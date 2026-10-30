# frozen_string_literal: true

module ResolutionAgent
  class Chat
    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[conclusion environment problem attempts log_reading direction file_changes],
      properties: {
        conclusion: { type: "string" },
        environment: { type: "string" },
        problem: { type: "string" },
        attempts: { type: "string" },
        log_reading: { type: "string" },
        direction: { type: "string" },
        file_changes: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[path content],
            properties: {
              path: { type: "string" },
              content: { type: "string" }
            }
          }
        }
      }
    }.freeze

    Result = Data.define(:success?, :error)

    def self.call(...)
      new(...).call
    end

    def initialize(user:, work_package:, body:, gitea_url: nil, branch: nil)
      @user = user
      @work_package = work_package
      @body = body.to_s.strip
      @gitea_url = gitea_url.presence
      @branch = branch.presence
      @setting = Setting.instance
    end

    def call
      return Result.new(success?: false, error: I18n.t("resolution_agent.errors.unavailable")) unless access.open?
      return Result.new(success?: false, error: I18n.t("resolution_agent.errors.empty")) if @body.blank?

      conversation = Conversation.for_work_package(@work_package)
      return Result.new(success?: false, error: I18n.t("resolution_agent.errors.busy")) unless claim(conversation)

      begin
        conversation.messages.create!(role: "user", body: @body)
        if (action = Decision.phrase(@body))
          Decision.call(user: @user, work_package: @work_package, action:)
        else
          reply(conversation)
        end
        Result.new(success?: true, error: nil)
      ensure
        conversation.update!(generating: false)
      end
    end

    private

    def access
      @access ||= Access.new(@user, @work_package, setting: @setting)
    end

    def claim(conversation)
      conversation.with_lock do
        return false if conversation.generating?

        conversation.update!(generating: true)
      end
      true
    end

    def reply(conversation)
      return unavailable(conversation) unless @setting.llm_ready?

      context = Context.new(@work_package, user: @user, vision: false)
      code = read_repository(context)
      if code.is_a?(Hash) && !code[:ok]
        conversation.messages.create!(role: "agent", body: I18n.t("resolution_agent.prompt.code_failed", error: code[:error]))
        conversation.runs.create!(
          outcome: "gitea_failed",
          gitea_repository: @gitea_url,
          source_branch: @branch,
          assignee_before_fix_id: @work_package.assigned_to_id
        )
        return
      end
      fields = ask(context, code_text: code.is_a?(Hash) ? code[:text] : nil)
      fields = apply_code_fix(conversation, fields)
      body = Summary.build(fields)
      conversation.messages.create!(role: "agent", body:, payload: fields.to_json)
      conversation.runs.create!(
        outcome: "chat",
        attachment_names: context.attachment_names.to_json,
        gitea_repository: @gitea_url,
        source_branch: @branch
      )
    rescue StandardError => e
      Rails.logger.warn { "Resolution agent failed for work package #{@work_package.id}: #{e.class}" }
      conversation.messages.create!(role: "agent", body: I18n.t("resolution_agent.errors.generation_failed"))
    end

    def read_repository(context)
      return if @gitea_url.blank? || @branch.blank?

      Gitea::SourceReader.new(
        setting: @setting,
        repository_url: @gitea_url,
        branch: @branch,
        prompt: "#{context.prompt}\n\n#{I18n.t('resolution_agent.prompt.user')}:\n#{@body}"
      ).call
    end

    def ask(context, code_text: nil)
      prompt = I18n.t(
        "resolution_agent.prompt.instructions",
        missing: I18n.t("resolution_agent.summary.missing"),
        no_log: I18n.t("resolution_agent.summary.no_log"),
        code_instruction:,
        code_section: code_section(code_text),
        materials: context.prompt,
        message: @body
      )
      chat = @setting.llm_chat
      chat = chat.with_schema(SCHEMA) if chat.respond_to?(:with_schema)
      message = context.image_paths.any? ? chat.ask(prompt, with: context.image_paths) : chat.ask(prompt)
      parse(message)
    rescue ArgumentError
      message = chat.ask(prompt)
      parse(message)
    end

    def parse(message)
      content = message.respond_to?(:content) ? message.content : message
      hash = content.is_a?(Hash) ? content : JSON.parse(content.to_s[/\{.*\}/m] || "{}")
      Llm::StructuredOutput.parse!(hash)
    end

    def code_section(code_text)
      return "" if code_text.nil?
      return I18n.t("resolution_agent.prompt.no_code") if code_text.blank?

      I18n.t("resolution_agent.prompt.files_read", text: code_text)
    end

    def code_instruction
      return I18n.t("resolution_agent.prompt.no_repository") if @gitea_url.blank? || @branch.blank?

      I18n.t("resolution_agent.prompt.repository_given", url: @gitea_url, branch: @branch)
    end

    def apply_code_fix(conversation, fields)
      return fields if @gitea_url.blank? || @branch.blank?

      assignee_before = @work_package.assigned_to_id
      result = Gitea::CodeFix.new(
        setting: @setting,
        repository_url: @gitea_url,
        branch: @branch,
        work_package: @work_package,
        changes: fields[:file_changes]
      ).call
      if result[:ok]
        fields[:direction] = [
          fields[:direction],
          I18n.t("resolution_agent.prompt.repository", repository: result[:repository]),
          I18n.t("resolution_agent.prompt.fix_branch", branch: result[:fix_branch]),
          I18n.t("resolution_agent.prompt.pull_request", url: result[:pull_request_url])
        ].compact.join("\n")
        conversation.runs.create!(
          outcome: "gitea_attempt",
          gitea_repository: result[:repository],
          source_branch: result[:source_branch],
          fix_branch: result[:fix_branch],
          pull_request_url: result[:pull_request_url],
          assignee_before_fix_id: assignee_before
        )
      else
        fields[:direction] = [fields[:direction], I18n.t("resolution_agent.prompt.code_failed", error: result[:error])].compact.join("\n")
        conversation.runs.create!(
          outcome: "gitea_failed",
          gitea_repository: @gitea_url,
          source_branch: @branch,
          assignee_before_fix_id: assignee_before
        )
      end
      fields
    end

    def unavailable(conversation)
      conversation.messages.create!(role: "agent", body: I18n.t("resolution_agent.errors.model_unready"))
    end
  end
end
