# frozen_string_literal: true

module ResolutionAgent
  class Conversation < ApplicationRecord
    GENERATION_STALE_AFTER = 15.minutes
    self.table_name = "resolution_agent_conversations"

    belongs_to :work_package
    has_many :messages, class_name: "ResolutionAgent::Message", dependent: :destroy
    has_many :runs, class_name: "ResolutionAgent::Run", dependent: :destroy

    def self.for_work_package(work_package)
      find_or_create_by!(work_package:)
    end

    def pending_assignee_list
      JSON.parse(pending_assignee_ids.presence || "[]")
    rescue JSON::ParserError
      []
    end

    def claim_generation!
      with_lock do
        return if generating? && !stale_generation?

        token = SecureRandom.uuid
        update!(
          generating: true,
          generation_token: token,
          generation_job_id: nil,
          generation_phase: "queued",
          generation_started_at: Time.current
        )
        token
      end
    end

    def attach_generation_job!(token, job_id)
      with_lock do
        return false unless generation_token == token

        update!(generation_job_id: job_id)
        true
      end
    end

    def update_generation_phase!(token, phase)
      with_lock do
        return false unless generation_token == token

        update!(generation_phase: phase)
        true
      end
    end

    def finish_generation!(token)
      with_lock do
        return false unless generation_token == token

        update!(
          generating: false,
          generation_token: nil,
          generation_phase: nil,
          generation_started_at: nil
        )
        true
      end
    end

    def generation_current?(token)
      generating? && generation_token == token
    end

    def recover_stale_generation!
      with_lock do
        return false unless generating? && stale_generation?

        update!(
          generating: false,
          generation_token: nil,
          generation_phase: nil,
          generation_started_at: nil
        )
        true
      end
    end

    private

    def stale_generation?
      return false if generation_started_at.blank? || generation_started_at > GENERATION_STALE_AFTER.ago
      return true if generation_job_id.blank?

      job = GoodJob::Job.find_by(id: generation_job_id)
      job.blank? || job.finished_at.present?
    end
  end
end
