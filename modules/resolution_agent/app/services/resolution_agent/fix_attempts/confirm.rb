# frozen_string_literal: true

module ResolutionAgent
  module FixAttempts
    class Confirm
      def initialize(attempt:, user:, setting: Setting.instance)
        @attempt = attempt
        @user = user
        @setting = setting
      end

      def call
        @attempt.with_lock do
          validate!
          @attempt.update!(status: "pushing")
          result = create_pull_request
          raise Gitea::Error, result[:error] unless result[:ok]

          @attempt.update!(
            status: "pull_request_opened",
            confirmed_by: @user,
            confirmed_at: Time.current,
            fix_branch: result[:fix_branch],
            pull_request_number: result[:pull_request_number],
            pull_request_url: result[:pull_request_url],
            pull_request_state: "open"
          )
          record_success(result)
          audit("pull_request.created", "success", pull_request_url: result[:pull_request_url])
          result
        rescue StandardError => e
          @attempt.update!(
            status: "failed",
            failure_kind: e.class.name,
            failure_detail: e.message.to_s.truncate(500)
          )
          audit("pull_request.created", "failure", error: e.class.name)
          raise
        end
      end

      private

      def validate!
        raise Gitea::Error, I18n.t("resolution_agent.errors.not_allowed") unless @attempt.work_package.assigned_to_id == @user.id
        raise Gitea::Error, I18n.t("resolution_agent.gitea.invalid_attempt_state") unless @attempt.status == "awaiting_confirmation"
        raise Gitea::Error, I18n.t("resolution_agent.gitea.unmapped_repository") unless @attempt.project_repository.active?

        repository = parsed_repository
        branch = Gitea::Client.new(repository, token: @setting.gitea_token).branch(@attempt.source_branch)
        current_sha = branch.dig("commit", "id")
        if @attempt.source_commit_sha.present? && current_sha != @attempt.source_commit_sha
          raise Gitea::Error, I18n.t("resolution_agent.gitea.stale_proposal")
        end
      end

      def create_pull_request
        Gitea::CodeFix.new(
          setting: @setting,
          repository_url: repository_url,
          branch: @attempt.source_branch,
          work_package: @attempt.work_package,
          changes: @attempt.changes,
          fix_branch: "agent/task-#{@attempt.work_package_id}/attempt-#{@attempt.attempt_uuid}"
        ).call
      end

      def record_success(result)
        @attempt.conversation.runs.create!(
          outcome: "gitea_attempt",
          gitea_repository: result[:repository],
          source_branch: result[:source_branch],
          fix_branch: result[:fix_branch],
          pull_request_url: result[:pull_request_url],
          assignee_before_fix_id: @attempt.work_package.assigned_to_id
        )
        body = I18n.t("resolution_agent.prompt.pull_request", url: result[:pull_request_url])
        @attempt.conversation.messages.create!(role: "notice", body:)
        ReplyRecorder.new(work_package: @attempt.work_package, agent: @setting.service_account, body:).call
      end

      def parsed_repository
        Gitea::Repository.parse(repository_url, @setting.gitea_base_url)
      end

      def repository_url
        base = @setting.gitea_base_url.to_s.sub(%r{/+\z}, "")
        "#{base}/#{@attempt.project_repository.full_name}"
      end

      def audit(action, result, metadata)
        AuditEvent.create!(
          actor: @user,
          project: @attempt.work_package.project,
          work_package: @attempt.work_package,
          project_repository: @attempt.project_repository,
          fix_attempt: @attempt,
          action:,
          result:,
          metadata:
        )
      end
    end
  end
end
