# frozen_string_literal: true

module ResolutionAgent
  class Conversation < ApplicationRecord
    self.table_name = "resolution_agent_conversations"

    belongs_to :work_package
    has_many :messages, class_name: "ResolutionAgent::Message", dependent: :destroy
    has_many :runs, class_name: "ResolutionAgent::Run", dependent: :destroy

    def self.for_work_package(work_package)
      find_or_create_by!(work_package:)
    end

    def pending_assignee_list
      JSON.parse(pending_assignee_ids.presence || "[]")
    rescue JSON::ParserError
      []
    end
  end
end
