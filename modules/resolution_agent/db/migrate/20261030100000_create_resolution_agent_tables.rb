# frozen_string_literal: true

class CreateResolutionAgentTables < ActiveRecord::Migration[8.1]
  def change
    create_table :resolution_agent_settings do |t|
      t.boolean :enabled, null: false, default: false
      t.bigint :service_account_id
      t.bigint :rd_supervisor_id
      t.bigint :status_acceptance_id
      t.bigint :status_in_progress_id
      t.bigint :status_in_acceptance_id
      t.bigint :status_closed_id
      t.string :gitea_base_url
      t.string :gitea_token
      t.timestamps
    end

    create_table :resolution_agent_conversations do |t|
      t.references :work_package, null: false, foreign_key: true, index: { unique: true }
      t.boolean :generating, null: false, default: false
      t.string :pending_action
      t.text :pending_summary
      t.text :pending_assignee_ids
      t.timestamps
    end

    create_table :resolution_agent_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :resolution_agent_conversations }
      t.string :role, null: false
      t.text :body, null: false
      t.text :payload
      t.bigint :journal_id
      t.timestamps
    end

    create_table :resolution_agent_runs do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :resolution_agent_conversations }
      t.string :outcome, null: false
      t.text :attachment_names
      t.string :gitea_repository
      t.string :source_branch
      t.string :fix_branch
      t.string :pull_request_url
      t.bigint :assignee_before_fix_id
      t.timestamps
    end
  end
end
