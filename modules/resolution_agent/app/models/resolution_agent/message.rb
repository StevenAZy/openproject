# frozen_string_literal: true

module ResolutionAgent
  class Message < ApplicationRecord
    self.table_name = "resolution_agent_messages"

    belongs_to :conversation, class_name: "ResolutionAgent::Conversation"

    def payload_hash
      JSON.parse(payload.presence || "{}")
    rescue JSON::ParserError
      {}
    end
  end
end
