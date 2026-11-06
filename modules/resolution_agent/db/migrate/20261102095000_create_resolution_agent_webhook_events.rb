# frozen_string_literal: true

class CreateResolutionAgentWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :resolution_agent_webhook_events do |t|
      t.string :delivery_id, null: false
      t.string :event_type, null: false
      t.bigint :gitea_repository_id
      t.string :payload_digest, null: false
      t.string :processing_status, null: false, default: "received"
      t.datetime :event_timestamp
      t.datetime :processed_at
      t.string :error_kind
      t.timestamps
    end

    add_index :resolution_agent_webhook_events, :delivery_id, unique: true
  end
end
