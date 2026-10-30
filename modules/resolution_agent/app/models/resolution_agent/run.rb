# frozen_string_literal: true

module ResolutionAgent
  class Run < ApplicationRecord
    self.table_name = "resolution_agent_runs"

    belongs_to :conversation, class_name: "ResolutionAgent::Conversation"

    def attachment_list
      JSON.parse(attachment_names.presence || "[]")
    rescue JSON::ParserError
      []
    end
  end
end
