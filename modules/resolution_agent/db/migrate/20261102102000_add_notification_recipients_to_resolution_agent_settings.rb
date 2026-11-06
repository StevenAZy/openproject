class AddNotificationRecipientsToResolutionAgentSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :resolution_agent_settings,
               :notification_recipient_ids,
               :jsonb,
               null: false,
               default: []
  end
end
