# frozen_string_literal: true

class AddGenerationTrackingToResolutionAgentConversations < ActiveRecord::Migration[8.1]
  def change
    change_table :resolution_agent_conversations, bulk: true do |t|
      t.string :generation_token
      t.string :generation_job_id
      t.string :generation_phase
      t.datetime :generation_started_at
    end
  end
end
