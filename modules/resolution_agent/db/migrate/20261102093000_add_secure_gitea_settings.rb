# frozen_string_literal: true

class AddSecureGiteaSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :resolution_agent_settings, :gitea_webhook_secret, :text
    add_column :resolution_agent_settings, :gitea_tls_mode, :string, null: false, default: "system_ca"
    add_column :resolution_agent_settings, :gitea_custom_ca, :text
    change_column :resolution_agent_settings, :gitea_token, :text
    change_column :resolution_agent_settings, :llm_api_key, :text
  end
end
