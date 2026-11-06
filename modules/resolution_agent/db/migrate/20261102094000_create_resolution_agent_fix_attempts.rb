# frozen_string_literal: true

class CreateResolutionAgentFixAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :resolution_agent_fix_attempts do |t|
      t.references :work_package, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { to_table: :resolution_agent_conversations }
      t.references :project_repository,
                   null: false,
                   foreign_key: { to_table: :resolution_agent_project_repositories },
                   index: false
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :attempt_uuid, null: false
      t.string :status, null: false, default: "awaiting_confirmation"
      t.string :source_branch, null: false
      t.string :source_commit_sha
      t.string :fix_branch
      t.text :encrypted_changes
      t.jsonb :diff_summary, null: false, default: {}
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.bigint :pull_request_number
      t.string :pull_request_url
      t.string :pull_request_state
      t.string :failure_kind
      t.text :failure_detail
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :resolution_agent_fix_attempts, :attempt_uuid, unique: true
    add_index :resolution_agent_fix_attempts, :fix_branch, unique: true, where: "fix_branch IS NOT NULL"
    add_index :resolution_agent_fix_attempts,
              :project_repository_id,
              name: "idx_resolution_agent_fix_attempts_repository"
  end
end
