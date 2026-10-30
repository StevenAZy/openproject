# frozen_string_literal: true

require "uri"

module ResolutionAgent
  module Gitea
    class Repository
      def self.parse(url, base_url)
        base = URI.parse(base_url.to_s)
        given = URI.parse(url.to_s)
        return unless given.scheme == base.scheme && given.host == base.host && given.port == base.port

        parts = given.path.delete_suffix(".git").split("/").reject(&:blank?)
        return if parts.length < 2

        new(owner: parts[-2], name: parts[-1], base:)
      rescue URI::InvalidURIError
        nil
      end

      attr_reader :owner, :name, :base

      def initialize(owner:, name:, base:)
        @owner = owner
        @name = name
        @base = base
      end

      def api_base
        "#{origin}/api/v1/repos/#{owner}/#{name}"
      end

      def web_base
        "#{origin}/#{owner}/#{name}"
      end

      def origin
        port = base.port
        suffix = port && [80, 443].exclude?(port) ? ":#{port}" : ""
        "#{base.scheme}://#{base.host}#{suffix}"
      end
    end
  end
end
