# frozen_string_literal: true

class CreateResolutionAgentAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :resolution_agent_audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.references :project, foreign_key: true
      t.references :work_package, foreign_key: true
      t.references :project_repository,
                   foreign_key: { to_table: :resolution_agent_project_repositories },
                   index: false
      t.references :fix_attempt,
                   foreign_key: { to_table: :resolution_agent_fix_attempts },
                   index: false
      t.string :action, null: false
      t.string :result, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id
      t.datetime :created_at, null: false
    end

    add_index :resolution_agent_audit_events,
              :project_repository_id,
              name: "idx_resolution_agent_audit_repository"
    add_index :resolution_agent_audit_events,
              :fix_attempt_id,
              name: "idx_resolution_agent_audit_attempt"
  end
end
