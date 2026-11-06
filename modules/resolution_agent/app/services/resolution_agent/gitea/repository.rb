# frozen_string_literal: true

require "uri"

module ResolutionAgent
  module Gitea
    class Repository
      def self.parse(url, base_url)
        base = URI.parse(base_url.to_s)
        given = URI.parse(url.to_s)
        return unless given.scheme == base.scheme && given.host == base.host && given.port == base.port

        base_path = base.path.to_s.sub(%r{/+\z}, "")
        return unless given.path == base_path || given.path.start_with?("#{base_path}/")

        relative_path = given.path.delete_prefix(base_path).delete_suffix(".git")
        parts = relative_path.split("/").reject(&:blank?)
        return unless parts.length == 2

        new(owner: parts[0], name: parts[1], base:)
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
        "#{site_base}/api/v1/repos/#{owner}/#{name}"
      end

      def web_base
        "#{site_base}/#{owner}/#{name}"
      end

      def site_base
        "#{origin}#{base.path.to_s.sub(%r{/+\z}, '')}"
      end

      def origin
        port = base.port
        suffix = port && [80, 443].exclude?(port) ? ":#{port}" : ""
        "#{base.scheme}://#{base.host}#{suffix}"
      end
    end
  end
end
