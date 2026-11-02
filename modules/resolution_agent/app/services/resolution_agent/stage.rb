# frozen_string_literal: true

module ResolutionAgent
  class Stage
    STAGE_OUTCOMES = %w[
      pe_resolved pe_unresolved fix_succeeded fix_failed
      test_passed test_failed supervisor_close
    ].freeze
    CODE_OUTCOMES = %w[gitea_attempt gitea_failed].freeze

    def initialize(runs)
      @runs = runs.sort_by { |run| run.id.to_i }
    end

    def name
      latest = stage_runs.last
      return "collecting" if latest.nil?

      case latest.outcome
      when "supervisor_close" then "closed"
      when "test_passed" then "awaiting_close"
      when "test_failed" then "testing_failed"
      when "fix_succeeded" then "in_testing"
      when "pe_resolved", "pe_unresolved", "fix_failed" then "with_rd"
      else "collecting"
      end
    end

    def action_allowed?(action)
      allowed_actions.include?(action.to_s)
    end

    def allowed_actions
      case name
      when "collecting"
        %w[pe_resolved pe_unresolved]
      when "with_rd"
        code_actions
      when "in_testing"
        %w[test_passed test_failed]
      when "testing_failed"
        %w[test_passed test_failed] + code_actions
      when "awaiting_close"
        %w[supervisor_close]
      else
        []
      end
    end

    def code_entry?
      %w[with_rd testing_failed].include?(name)
    end

    def latest_test_passed?
      name == "awaiting_close"
    end

    def assignee_before_fix_id
      code_runs.reverse_each.find { |run| !run.assignee_before_fix_id.nil? }&.assignee_before_fix_id
    end

    private

    def code_actions
      actions = []
      actions << "fix_succeeded" if successful_fix?
      actions << "fix_failed" if code_attempt?
      actions
    end

    def successful_fix?
      code_runs.any? { |run| run.outcome == "gitea_attempt" && !run.pull_request_url.to_s.empty? }
    end

    def code_attempt?
      code_runs.any?
    end

    def stage_runs
      @runs.select { |run| STAGE_OUTCOMES.include?(run.outcome) }
    end

    def code_runs
      start_id = window_start_id
      return [] if start_id.nil?

      @runs.select { |run| CODE_OUTCOMES.include?(run.outcome) && run.id.to_i > start_id.to_i }
    end

    def window_start_id
      return unless %w[with_rd testing_failed].include?(name)

      stage_runs.last&.id
    end
  end
end
