# frozen_string_literal: true

module ResolutionAgent
  class GenerateReplyJob < ApplicationJob
    queue_with_priority :above_normal

    def perform(user:, work_package:, conversation_id:, token:, body:, gitea_url: nil, branch: nil, repository_id: nil)
      @user = user
      @work_package = work_package
      @conversation = Conversation.find(conversation_id)
      @token = token

      User.execute_as(user) do
        OpenProject::LocaleHelper.with_locale_for(user) do
          run(body:, gitea_url:, branch:, repository_id:)
        end
      end
    ensure
      @conversation&.finish_generation!(token)
    end

    def store_status? = false

    def title
      I18n.t("resolution_agent.job.title")
    end

    private

    attr_reader :conversation, :token, :user, :work_package

    def run(body:, gitea_url:, branch:, repository_id:)
      raise Chat::StaleGeneration unless conversation.generation_current?(token)

      Chat.new(user:, work_package:, body:, gitea_url:, branch:, repository_id:).generate(
        conversation:,
        token:,
        on_phase: method(:set_phase)
      )
      set_phase("completed")
    rescue Chat::StaleGeneration
      nil
    rescue StandardError => e
      fail_generation(e)
    end

    def set_phase(phase)
      raise Chat::StaleGeneration unless conversation.update_generation_phase!(token, phase)
    end

    def fail_generation(error)
      kind = error_kind(error)
      store_failure_notice(kind)
      Rails.logger.warn do
        failure_log(error)
      end
      conversation.update_generation_phase!(token, "failed")
    end

    def store_failure_notice(kind)
      return unless conversation.generation_current?(token)

      conversation.messages.create!(role: "notice", body: I18n.t("resolution_agent.errors.#{kind}"))
    end

    def failure_log(error)
      "Resolution agent job #{job_id} failed for work package #{work_package.id} " \
        "during #{conversation.generation_phase}: #{error.class}"
    end

    def error_kind(error)
      case error
      when Llm::Errors::TimeoutError then "timeout"
      when Llm::Errors::AuthenticationError then "authentication"
      when Llm::Errors::ConfigurationError then "configuration"
      when Llm::Errors::RateLimitedError then "rate_limited"
      when Llm::Errors::ConnectionError then "connection"
      when Llm::Errors::ParseError then "invalid_response"
      else "generation_failed"
      end
    end
  end
end
