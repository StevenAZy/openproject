# frozen_string_literal: true

class AddUserToResolutionAgentMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :resolution_agent_messages, :user, foreign_key: { on_delete: :nullify }
  end
end
