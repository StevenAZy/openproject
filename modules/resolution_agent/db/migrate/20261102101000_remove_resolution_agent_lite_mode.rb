# frozen_string_literal: true

class RemoveResolutionAgentLiteMode < ActiveRecord::Migration[8.1]
  def up
    remove_column :resolution_agent_settings, :lite_mode if column_exists?(:resolution_agent_settings, :lite_mode)
  end

  def down
    add_column :resolution_agent_settings, :lite_mode, :boolean, null: false, default: true unless
      column_exists?(:resolution_agent_settings, :lite_mode)
  end
end
