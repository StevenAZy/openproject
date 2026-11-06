# frozen_string_literal: true

module ResolutionAgent
  class FixAttempt < ApplicationRecord
    include Redmine::Ciphering

    self.table_name = "resolution_agent_fix_attempts"

    belongs_to :work_package
    belongs_to :conversation
    belongs_to :project_repository
    belongs_to :actor, class_name: "User"
    belongs_to :confirmed_by, class_name: "User", optional: true

    validates :attempt_uuid, :status, :source_branch, presence: true
    validates :attempt_uuid, uniqueness: true

    scope :awaiting_confirmation, -> { where(status: "awaiting_confirmation") }

    def changes
      JSON.parse(read_ciphered_attribute(:encrypted_changes).presence || "[]")
    end

    def changes=(value)
      write_ciphered_attribute(:encrypted_changes, JSON.generate(value))
    end
  end
end
