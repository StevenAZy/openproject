# frozen_string_literal: true

require "openssl"

module ResolutionAgent
  class GiteaWebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token
    no_authorization_required! :create

    def create
      body = request.raw_post
      return head :unauthorized unless valid_signature?(body)

      delivery_id = request.headers["X-Gitea-Delivery"].presence
      return head :bad_request if delivery_id.blank?
      return head :ok if WebhookEvent.exists?(delivery_id:)

      payload = JSON.parse(body)
      event = create_event(delivery_id, payload, body)
      process_pull_request(event, payload) if event.event_type == "pull_request"
      event.update!(processing_status: "processed", processed_at: Time.current)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue ActiveRecord::RecordNotUnique
      head :ok
    rescue StandardError => e
      event&.update(processing_status: "failed", error_kind: e.class.name)
      Rails.logger.warn("Resolution Agent Gitea webhook failed: #{e.class}")
      head :unprocessable_entity
    end

    private

    def valid_signature?(body)
      secret = Setting.instance.gitea_webhook_secret.to_s
      supplied = request.headers["X-Gitea-Signature"].to_s
      return false if secret.blank? || supplied.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      supplied.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
    end

    def create_event(delivery_id, payload, body)
      timestamp = event_timestamp(payload)
      if timestamp && (timestamp < 24.hours.ago || timestamp > 5.minutes.from_now)
        raise Gitea::Error, "Webhook event is outside the accepted time window"
      end

      WebhookEvent.create!(
        delivery_id:,
        event_type: request.headers["X-Gitea-Event"].to_s,
        gitea_repository_id: payload.dig("repository", "id"),
        payload_digest: Digest::SHA256.hexdigest(body),
        event_timestamp: timestamp
      )
    end

    def event_timestamp(payload)
      value = payload.dig("pull_request", "updated_at") || payload["timestamp"]
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end

    def process_pull_request(_event, payload)
      pull = payload.fetch("pull_request")
      attempt = FixAttempt.find_by!(
        project_repository_id: ProjectRepository.where(gitea_repository_id: payload.dig("repository", "id")).select(:id),
        pull_request_number: pull["number"],
        fix_branch: pull.dig("head", "ref")
      )
      state = pull["merged"] ? "merged" : pull["state"].to_s
      return if attempt.pull_request_state == state

      attempt.update!(status: state, pull_request_state: state)
      AuditEvent.create!(
        project: attempt.work_package.project,
        work_package: attempt.work_package,
        project_repository: attempt.project_repository,
        fix_attempt: attempt,
        action: "webhook.pull_request",
        result: "success",
        metadata: { state: }
      )
      record_activity(attempt, state)
    end

    def record_activity(attempt, state)
      agent = Setting.instance.service_account
      return if agent.blank?

      User.execute_as(agent) do
        WorkPackages::UpdateService
          .new(user: agent, model: attempt.work_package)
          .call(journal_notes: I18n.t("resolution_agent.gitea.webhook_state", state:, url: attempt.pull_request_url))
      end
    end
  end
end
