# frozen_string_literal: true

module ResolutionAgent
  class Setting < ApplicationRecord
    self.table_name = "resolution_agent_settings"

    BUILTIN_STATUSES = {
      "pe_resolved" => "Tested",
      "pe_unresolved" => "In progress",
      "fix_succeeded" => "In testing",
      "supervisor_close" => "Closed"
    }.freeze

    Endpoint = Data.define(:api_format, :base_url, :api_key, :custom_headers)

    belongs_to :service_account, class_name: "User", optional: true
    belongs_to :rd_supervisor, class_name: "User", optional: true

    def self.instance
      first || create!
    end

    def self.enabled?
      return false unless table_exists?

      instance.enabled?
    rescue StandardError
      false
    end

    def status_for(outcome)
      name = BUILTIN_STATUSES[outcome.to_s]
      return if name.blank?

      Status.find_by(name:)
    end

    def llm_ready?
      llm_base_url.present? && llm_model.present?
    end

    def llm_chat
      Llm::Session.for(endpoint).chat(llm_model)
    end

    def endpoint
      Endpoint.new(api_format: "openai", base_url: llm_base_url, api_key: llm_api_key, custom_headers: {})
    end

    def inspect
      text = super
      [gitea_token, llm_api_key].each do |secret|
        text = text.gsub(secret, "[redacted]") if secret.present?
      end
      text
    end
  end
end
