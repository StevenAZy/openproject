# frozen_string_literal: true

module ResolutionAgent
  class Setting < ApplicationRecord
    include Redmine::Ciphering

    self.table_name = "resolution_agent_settings"

    OUTCOME_STATUS_COLUMNS = {
      "pe_resolved" => :status_closed_id,
      "pe_unresolved" => :status_rd_working_id,
      "fix_succeeded" => :status_pe_verification_id,
      "test_passed" => :status_closed_id,
      "test_failed" => :status_rd_working_id
    }.freeze

    Endpoint = Data.define(:api_format, :base_url, :api_key, :custom_headers)

    belongs_to :service_account, class_name: "User", optional: true
    belongs_to :rd_supervisor, class_name: "User", optional: true

    validates :gitea_tls_mode, inclusion: { in: %w[system_ca custom_ca] }, allow_nil: true
    before_validation :normalize_notification_recipient_ids

    def self.instance
      RequestStore.fetch(:resolution_agent_setting_instance) { first || create! }
    end

    def self.enabled?
      return false unless table_exists?

      instance.enabled?
    rescue StandardError
      false
    end

    def status_for(outcome)
      column = OUTCOME_STATUS_COLUMNS[outcome.to_s]
      return if column.blank?

      Status.find_by(id: public_send(column))
    end

    def status_label_for(outcome)
      column = OUTCOME_STATUS_COLUMNS[outcome.to_s]
      column ? I18n.t("resolution_agent.settings.#{column.to_s.delete_suffix('_id')}") : outcome
    end

    def llm_ready?
      llm_base_url.present? && llm_model.present?
    end

    def llm_chat(max_retries: 1)
      Llm::Session.for(endpoint, max_retries:).chat(llm_model)
    end

    def notification_recipients
      User.not_locked.where(type: "User", id: notification_recipient_ids)
    end

    def endpoint
      Endpoint.new(api_format: "openai", base_url: llm_base_url, api_key: llm_api_key, custom_headers: {})
    end

    %i[gitea_token gitea_webhook_secret llm_api_key].each do |attribute|
      define_method(attribute) { read_ciphered_attribute(attribute) }
      define_method(:"#{attribute}=") { |value| write_ciphered_attribute(attribute, value) }
    end

    def inspect
      text = super
      [gitea_token, gitea_webhook_secret, llm_api_key].each do |secret|
        text = text.gsub(secret, "[redacted]") if secret.present?
      end
      text
    end

    private

    def normalize_notification_recipient_ids
      self.notification_recipient_ids = Array(notification_recipient_ids).filter_map do |id|
        parsed_id = Integer(id, exception: false)
        parsed_id if parsed_id&.positive?
      end.uniq
    end
  end
end
