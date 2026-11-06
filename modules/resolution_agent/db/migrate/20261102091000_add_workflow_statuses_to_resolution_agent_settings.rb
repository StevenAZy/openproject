# frozen_string_literal: true

class AddWorkflowStatusesToResolutionAgentSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :resolution_agent_settings, :status_waiting_rd_id, :bigint
    add_column :resolution_agent_settings, :status_rd_working_id, :bigint
    add_column :resolution_agent_settings, :status_pe_verification_id, :bigint
    add_column :resolution_agent_settings, :status_closed_id, :bigint
  end
end
