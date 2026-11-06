# frozen_string_literal: true

module ResolutionAgent
  class ProjectRepository < ApplicationRecord
    self.table_name = "resolution_agent_project_repositories"

    belongs_to :project
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true

    validates :owner, :name, :display_name, presence: true
    validates :name, uniqueness: { scope: %i[project_id owner], case_sensitive: false }

    scope :active, -> { where(active: true) }

    def full_name
      "#{owner}/#{name}"
    end
  end
end
