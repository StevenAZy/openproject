# frozen_string_literal: true

class AddLlmAndRemoveStatusMappingFromResolutionAgentSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :resolution_agent_settings, :status_acceptance_id, :bigint
    remove_column :resolution_agent_settings, :status_in_progress_id, :bigint
    remove_column :resolution_agent_settings, :status_in_acceptance_id, :bigint
    remove_column :resolution_agent_settings, :status_closed_id, :bigint
    add_column :resolution_agent_settings, :llm_base_url, :string
    add_column :resolution_agent_settings, :llm_api_key, :string
    add_column :resolution_agent_settings, :llm_model, :string
  end
end
