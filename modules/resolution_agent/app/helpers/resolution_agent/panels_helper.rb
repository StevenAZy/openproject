# frozen_string_literal: true

module ResolutionAgent
  module PanelsHelper
    DETAIL_KEYS = %w[environment problem attempts log_reading].freeze

    def stage_caption
      t("resolution_agent.stages.#{@stage.name}.#{stage_audience}")
    end

    def empty_caption
      return t("resolution_agent.empty.author") if @stage.name == "collecting" && @access.author?

      stage_caption
    end

    def show_composer?
      @runtime_ready && !closed_stage?
    end

    def show_outcome_bar?
      !closed_stage? && (pending_choice? || decision_buttons.any?)
    end

    def show_code_fields?
      show_composer? && @access.assignee? && @stage.code_entry?
    end

    def generating?
      @conversation&.generating?
    end

    def generation_caption
      phase = @conversation&.generation_phase.presence || "queued"
      t("resolution_agent.generation_phases.#{phase}", default: t("resolution_agent.generating_reply"))
    end

    def generation_poll_path
      status_project_work_package_resolution_agent_path(
        @project,
        @work_package,
        job: @conversation&.generation_job_id
      )
    end

    def generation_started_at_ms
      @conversation&.generation_started_at&.then { |time| (time.to_f * 1000).round } || 0
    end

    def generation_elapsed
      return 0 if @conversation&.generation_started_at.blank?

      [(Time.current - @conversation.generation_started_at).floor, 0].max
    end

    def pending_choice?
      @access.author? && @candidates.any?
    end

    def closed_stage?
      @stage.name == "closed"
    end

    def decision_buttons
      return [] if pending_choice? || closed_stage?

      visible_actions.filter_map do |action|
        next unless @access.allowed_decision?(action)

        {
          action:,
          label: t("resolution_agent.actions.#{action}"),
          effect: t("resolution_agent.effects.#{action}")
        }
      end
    end

    def resolution_agent_body(text)
      escaped = ERB::Util.html_escape(text.to_s)
      linked = escaped.gsub(%r{https?://[^\s<]+}) do |url|
        %(<a href="#{url}" rel="noopener noreferrer">#{url}</a>)
      end
      linked.gsub("\n", "<br>").html_safe
    end

    def agent_structured?(message)
      message.payload_hash.values_at(*DETAIL_KEYS, "direction").any?(&:present?)
    end

    def animate_agent_message?(message)
      return false unless @polled_job_finished

      @messages.to_a.reverse.find { |item| item.role == "agent" } == message
    end

    def agent_direction(message)
      message.payload_hash["direction"].to_s.strip.presence || t("resolution_agent.summary.missing")
    end

    def agent_details(message)
      hash = message.payload_hash
      DETAIL_KEYS.map do |key|
        value = hash[key].to_s.strip
        value = t("resolution_agent.summary.missing") if value.blank?
        value = t("resolution_agent.summary.no_log") if key == "log_reading" && value == t("resolution_agent.summary.missing")
        [t("resolution_agent.summary.#{key}"), value]
      end
    end

    def outcome_status_line(message)
      payload = message.payload_hash
      if payload["status_changed"]
        t("resolution_agent.outcome.status_changed", status: payload["status_name"])
      else
        t("resolution_agent.outcome.status_unchanged")
      end
    end

    def outcome_assignee_line(message)
      payload = message.payload_hash
      if payload["assignee_changed"]
        t("resolution_agent.outcome.assignee_changed", name: payload["assignee_name"])
      else
        t("resolution_agent.outcome.assignee_unchanged")
      end
    end

    def outcome_conclusion(message)
      message.payload_hash["conclusion"].presence || message.body
    end

    private

    def visible_actions
      actions = @stage.allowed_actions
      return actions unless @access.author? && @access.assignee?

      case @stage.name
      when "collecting"
        actions & %w[pe_resolved pe_unresolved]
      when "with_rd"
        actions & %w[fix_succeeded fix_failed]
      when "in_testing"
        actions & %w[test_passed test_failed]
      when "testing_failed"
        actions
      when "awaiting_close"
        actions & %w[supervisor_close]
      else
        []
      end
    end

    def stage_audience
      case @stage.name
      when "collecting"
        @access.author? ? "author" : "other"
      when "with_rd"
        @access.assignee? ? "assignee" : "other"
      when "in_testing"
        @access.author? ? "author" : "other"
      when "testing_failed"
        if @access.author? && @access.assignee?
          "both"
        elsif @access.author?
          "author"
        elsif @access.assignee?
          "assignee"
        else
          "other"
        end
      when "awaiting_close"
        @access.supervisor? ? "supervisor" : "other"
      else
        "all"
      end
    end
  end
end
