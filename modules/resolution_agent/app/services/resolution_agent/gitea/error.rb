# frozen_string_literal: true

module ResolutionAgent
  module Gitea
    class Error < StandardError; end

    class ConnectionError < Error
      attr_reader :kind

      def initialize(kind, message)
        @kind = kind
        super(message)
      end
    end
  end
end
