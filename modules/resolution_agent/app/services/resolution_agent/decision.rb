# frozen_string_literal: true

module ResolutionAgent
  class Decision
    PHRASES = {
      "pe_resolved" => %w[已解决 方案有效],
      "pe_unresolved" => %w[未解决 方案无效],
      "fix_succeeded" => %w[修复有效],
      "fix_failed" => %w[修复失败],
      "test_passed" => %w[测试通过],
      "test_failed" => %w[测试未通过]
    }.freeze

    def self.phrase(text)
      stripped = text.to_s.strip
      PHRASES.each { |action, phrases| return action if phrases.include?(stripped) }
      %i[en zh-CN].each do |locale|
        I18n.t("resolution_agent.actions", locale:).each do |action, label|
          return action.to_s if label.to_s == stripped
        end
      end
      nil
    end

    def self.call(...)
      new(...).call
    end

    def initialize(user:, work_package:, action:, assignee_id: nil)
      @user = user
      @work_package = work_package
      @action = action.to_s
      @assignee_id = assignee_id
      @setting = Setting.instance
      @access = Access.new(user, work_package, setting: @setting)
    end

    def call
      conversation = Conversation.for_work_package(@work_package)
      return notice(conversation, I18n.t("resolution_agent.errors.not_allowed")) unless @access.allowed_decision?(@action)

      stage = Stage.new(conversation.runs.to_a)
      return notice(conversation, I18n.t("resolution_agent.errors.not_allowed")) unless stage.action_allowed?(@action)
      return notice(conversation, I18n.t("resolution_agent.errors.missing_agent")) if @setting.service_account.blank?

      fields = fields_for(conversation)
      summary = summary_for(fields)
      attributes = attributes_for(conversation, summary)
      return attributes if attributes.is_a?(ResolutionAgent::Message)

      status, detail = WorkPackageChange.new(@work_package, agent: @setting.service_account).call(attributes:, summary:)
      if status == :error
        notice(conversation, I18n.t("resolution_agent.errors.workflow", reason: detail))
      else
        record_outcome(conversation, fields, attributes, detail)
        conversation.runs.create!(outcome: @action, pull_request_url: latest_pull_request(conversation))
        conversation.update!(pending_action: nil, pending_summary: nil, pending_assignee_ids: nil)
      end
    end

    private

    def fields_for(conversation)
      fields = latest_agent_fields(conversation)
      last_user = conversation.messages.where(role: "user").order(:id).last&.body
      if %w[test_passed test_failed].include?(@action) && last_user.present?
        fields[:attempts] = [fields[:attempts], last_user].compact.join("\n")
      end
      if @action == "fix_succeeded"
        url = latest_pull_request(conversation)
        fields[:direction] = [fields[:direction], url].compact.join("\n") if url.present?
      end
      fields.merge(conclusion: I18n.t("resolution_agent.conclusions.#{@action}"))
    end

    def latest_agent_fields(conversation)
      conversation.messages.where(role: "agent").order(id: :desc).each do |message|
        fields = message.payload_hash.symbolize_keys
        return fields if fields.keys.intersect?(Summary::SECTIONS)
        return { direction: fields[:answer] } if fields[:answer].present?
        return { direction: message.body } if message.body.present?
      end
      {}
    end

    def summary_for(fields)
      original = @action == "pe_unresolved" ? @work_package.description.to_s : nil
      Summary.build(fields, original:)
    end

    def attributes_for(conversation, summary)
      attributes = {}
      status = @setting.status_for(@action)
      if %w[pe_resolved pe_unresolved fix_succeeded test_passed test_failed].include?(@action)
        if status.blank?
          return notice(conversation, I18n.t("resolution_agent.errors.missing_status", status: @setting.status_label_for(@action)))
        end

        attributes[:status_id] = status.id
      end
      attributes[:description] = summary if @action == "pe_unresolved"
      assignee = assignee_id_for(conversation, summary)
      return assignee if assignee.is_a?(ResolutionAgent::Message)

      attributes[:assigned_to_id] = assignee if assignee
      attributes
    end

    def assignee_id_for(conversation, summary)
      return forced_assignee(conversation) if @assignee_id.present?
      return fix_failed_assignee(conversation) if @action == "fix_failed"
      return nil unless %w[pe_resolved pe_unresolved].include?(@action)

      result = AssigneeResolver.new(@work_package, user: @user, supervisor: @setting.rd_supervisor).call
      case result.status
      when :ok
        result.assignees.first.id
      when :choose
        conversation.update!(
          pending_action: @action,
          pending_summary: summary,
          pending_assignee_ids: result.assignees.map(&:id).to_json
        )
        notice(conversation, I18n.t("resolution_agent.choose_assignee"))
      when :related_without_assignee
        note(conversation, I18n.t("resolution_agent.errors.related_without_assignee"))
      else
        note(conversation, I18n.t("resolution_agent.errors.missing_supervisor"))
      end
    end

    def forced_assignee(conversation)
      allowed = conversation.pending_assignee_list.map(&:to_i)
      return notice(conversation, I18n.t("resolution_agent.errors.not_allowed")) unless allowed.include?(@assignee_id.to_i)

      @assignee_id.to_i
    end

    def fix_failed_assignee(conversation)
      assignee_id = Stage.new(conversation.runs.to_a).assignee_before_fix_id
      return assignee_id if assignee_id.present?

      note(conversation, I18n.t("resolution_agent.errors.missing_previous_assignee"))
    end

    def record_outcome(conversation, fields, attributes, journal_id)
      status_name = Status.find_by(id: attributes[:status_id])&.name if attributes[:status_id]
      assignee_name = Principal.find_by(id: attributes[:assigned_to_id])&.name if attributes[:assigned_to_id]
      conversation.messages.create!(
        role: "outcome",
        body: fields[:conclusion].to_s,
        journal_id:,
        payload: {
          conclusion: fields[:conclusion],
          status_changed: attributes.key?(:status_id),
          status_name:,
          assignee_changed: attributes.key?(:assigned_to_id),
          assignee_name:
        }.to_json
      )
    end

    def latest_pull_request(conversation)
      conversation.runs.where.not(pull_request_url: nil).order(:id).last&.pull_request_url
    end

    def notice(conversation, body)
      conversation.messages.create!(role: "notice", body:)
    end

    def note(conversation, body)
      notice(conversation, body)
      nil
    end
  end
end
