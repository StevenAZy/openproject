# frozen_string_literal: true

module ResolutionAgent
  class WebhookEvent < ApplicationRecord
    self.table_name = "resolution_agent_webhook_events"

    validates :delivery_id, :event_type, :payload_digest, presence: true
    validates :delivery_id, uniqueness: true
  end
end
