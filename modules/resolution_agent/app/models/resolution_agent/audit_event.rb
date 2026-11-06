# frozen_string_literal: true

module ResolutionAgent
  class AuditEvent < ApplicationRecord
    self.table_name = "resolution_agent_audit_events"

    belongs_to :actor, class_name: "User", optional: true
    belongs_to :project, optional: true
    belongs_to :work_package, optional: true
    belongs_to :project_repository, optional: true
    belongs_to :fix_attempt, optional: true

    validates :action, :result, presence: true

    before_update { throw :abort }
    before_destroy { throw :abort }

    def readonly?
      persisted?
    end
  end
end
