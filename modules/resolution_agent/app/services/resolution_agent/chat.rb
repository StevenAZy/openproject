# frozen_string_literal: true

module ResolutionAgent
  class Chat
    class StaleGeneration < StandardError; end

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[answer file_changes],
      properties: {
        answer: { type: "string" },
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

    Result = Data.define(:success?, :error, :job_id)

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
      return failure("unavailable") unless access.open?
      return failure("empty") if @body.blank?

      conversation = Conversation.for_work_package(@work_package)
      token = conversation.claim_generation!
      return failure("busy") unless token

      enqueue_reply(conversation, token)
    end

    def generate(conversation:, token:, on_phase:)
      raise StaleGeneration unless conversation.generation_current?(token)
      return unavailable(conversation, token) unless access.open? && @setting.llm_ready?

      reply(conversation, token:, on_phase:)
    end

    private

    def enqueue_reply(conversation, token)
      message = conversation.messages.create!(role: "user", body: @body, user: @user)
      job = GenerateReplyJob.perform_later(**job_arguments(conversation, token))
      conversation.attach_generation_job!(token, job.job_id)
      Result.new(success?: true, error: nil, job_id: job.job_id)
    rescue StandardError => e
      conversation.finish_generation!(token)
      message&.destroy!
      log_enqueue_failure(e)
      failure("enqueue_failed")
    end

    def job_arguments(conversation, token)
      {
        user: @user,
        work_package: @work_package,
        conversation_id: conversation.id,
        token:,
        body: @body,
        gitea_url: @gitea_url,
        branch: @branch
      }
    end

    def log_enqueue_failure(error)
      Rails.logger.error do
        "Failed to enqueue resolution agent for work package #{@work_package.id}: #{error.class}"
      end
    end

    def access
      @access ||= Access.new(@user, @work_package, setting: @setting)
    end

    def failure(key)
      Result.new(success?: false, error: I18n.t("resolution_agent.errors.#{key}"), job_id: nil)
    end

    def reply(conversation, token:, on_phase:)
      @code_request = code_request?(conversation)
      on_phase.call("analyzing")
      context = Context.new(@work_package, user: @user, vision: false)
      code = code_context(context, on_phase)
      if code.is_a?(Hash) && !code[:ok]
        return record_repository_failure(conversation, token, code[:error])
      end

      on_phase.call("generating")
      fields = ask(context, code_text: code.is_a?(Hash) ? code[:text] : nil)
      ensure_current!(conversation, token)
      fields = apply_requested_fix(conversation, fields, token, on_phase)
      persist_reply(conversation, context, fields)
    end

    def code_context(context, on_phase)
      return unless @code_request

      on_phase.call("reading_repository")
      read_repository(context)
    end

    def record_repository_failure(conversation, token, error)
      ensure_current!(conversation, token)
      notice(conversation, I18n.t("resolution_agent.prompt.code_failed", error:))
      conversation.runs.create!(
        outcome: "gitea_failed",
        gitea_repository: @gitea_url,
        source_branch: @branch,
        assignee_before_fix_id: @work_package.assigned_to_id
      )
    end

    def apply_requested_fix(conversation, fields, token, on_phase)
      return fields unless @code_request

      on_phase.call("creating_fix")
      apply_code_fix(conversation, fields).tap { ensure_current!(conversation, token) }
    end

    def persist_reply(conversation, context, fields)
      body = fields[:answer].to_s.strip
      raise Llm::Errors::ParseError, "The agent answer is blank" if body.blank?

      message = conversation.messages.create!(role: "agent", body:, payload: fields.to_json)
      record_reply(conversation, message)
      conversation.runs.create!(
        outcome: "chat",
        attachment_names: context.attachment_names.to_json,
        gitea_repository: (@gitea_url if @code_request),
        source_branch: (@branch if @code_request)
      )
    end

    def code_request?(conversation)
      @gitea_url.present? &&
        @branch.present? &&
        access.assignee? &&
        Stage.new(conversation.runs.to_a).code_entry?
    end

    def read_repository(context)
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
        code_instruction:,
        code_section: code_section(code_text),
        materials: context.prompt,
        message: @body
      )
      chat = @setting.llm_chat(max_retries: 0)
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
      return I18n.t("resolution_agent.prompt.no_repository") unless @code_request

      I18n.t("resolution_agent.prompt.repository_given", url: @gitea_url, branch: @branch)
    end

    def apply_code_fix(conversation, fields)
      return fields unless @code_request

      assignee_before = @work_package.assigned_to_id
      result = Gitea::CodeFix.new(
        setting: @setting,
        repository_url: @gitea_url,
        branch: @branch,
        work_package: @work_package,
        changes: fields[:file_changes]
      ).call
      if result[:ok]
        fields[:answer] = [
          fields[:answer],
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
        fields[:answer] = [
          fields[:answer],
          I18n.t("resolution_agent.prompt.code_failed", error: result[:error])
        ].compact.join("\n")
        conversation.runs.create!(
          outcome: "gitea_failed",
          gitea_repository: @gitea_url,
          source_branch: @branch,
          assignee_before_fix_id: assignee_before
        )
      end
      fields
    end

    def record_reply(conversation, message)
      result = ReplyRecorder.new(
        work_package: @work_package,
        agent: @setting.service_account,
        body: message.body
      ).call
      if result.success?
        message.update!(journal_id: result.journal_id)
      else
        notice(conversation, I18n.t("resolution_agent.errors.record_reply_failed", reason: result.error))
      end
    end

    def ensure_current!(conversation, token)
      raise StaleGeneration unless conversation.reload.generation_current?(token)
    end

    def unavailable(conversation, token)
      ensure_current!(conversation, token)
      notice(conversation, I18n.t("resolution_agent.errors.model_unready"))
    end

    def notice(conversation, body)
      conversation.messages.create!(role: "notice", body:)
    end
  end
end
