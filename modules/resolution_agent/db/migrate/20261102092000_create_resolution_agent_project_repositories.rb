# frozen_string_literal: true

class CreateResolutionAgentProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :resolution_agent_project_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.bigint :gitea_repository_id
      t.string :owner, null: false
      t.string :name, null: false
      t.string :display_name, null: false
      t.string :default_branch
      t.boolean :active, null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :resolution_agent_project_repositories,
              %i[project_id owner name],
              unique: true,
              name: "idx_resolution_agent_project_repositories_identity"
    add_index :resolution_agent_project_repositories,
              %i[project_id gitea_repository_id],
              unique: true,
              where: "gitea_repository_id IS NOT NULL",
              name: "idx_resolution_agent_project_repositories_external"
  end
end
