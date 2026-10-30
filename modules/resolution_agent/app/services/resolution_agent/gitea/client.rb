# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "uri"
require "cgi"

module ResolutionAgent
  module Gitea
    class Client
      def initialize(repository, token:)
        @repository = repository
        @token = token
      end

      def tree_paths(branch, limit: 200)
        ref = request(:get, "/git/trees/#{escape(branch)}?recursive=1")
        Array(ref["tree"]).filter_map { |entry| entry["path"] if entry["type"] == "blob" }.first(limit)
      end

      def file(path, branch)
        request(:get, "/contents/#{escape_path(path)}?ref=#{escape(branch)}")
      end

      def text_file(path, branch, max_bytes: 100_000)
        payload = file(path, branch)
        return unless payload.is_a?(Hash) && payload["encoding"] == "base64"

        decoded = Base64.decode64(payload["content"].to_s)
        return if decoded.bytesize > max_bytes || decoded.include?("\0")

        decoded.force_encoding(Encoding::UTF_8).scrub
      end

      def ensure_branch(new_branch, from_branch)
        request(:post, "/branches", { new_branch_name: new_branch, old_branch_name: from_branch })
      rescue Error => e
        raise unless e.message.include?("409")
      end

      def write_file(path, branch, content, message)
        existing = file(path, branch)
        body = {
          branch:,
          content: Base64.strict_encode64(content),
          message:
        }
        if existing.is_a?(Hash) && existing["sha"]
          body[:sha] = existing["sha"]
          request(:put, "/contents/#{escape_path(path)}", body)
        else
          request(:post, "/contents/#{escape_path(path)}", body)
        end
      rescue Error => e
        raise unless e.message.include?("404")

        request(:post, "/contents/#{escape_path(path)}", {
                  branch:,
                  content: Base64.strict_encode64(content),
                  message:
                })
      end

      def pull_request(head:, base:, title:, body:)
        existing = request(:get, "/pulls?state=open")
        found = Array(existing).find { |pull| pull.dig("head", "ref") == head && pull.dig("base", "ref") == base }
        return found["html_url"] if found

        created = request(:post, "/pulls", { head:, base:, title:, body: })
        created["html_url"]
      end

      private

      def request(method, path, body = nil)
        uri = URI("#{@repository.api_base}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 15
        http.read_timeout = 30
        klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }.fetch(method)
        req = klass.new(uri)
        req["Authorization"] = "token #{@token}"
        req["Content-Type"] = "application/json"
        req["Accept"] = "application/json"
        req.body = JSON.generate(body) if body
        response = http.request(req)
        parsed = response.body.present? ? JSON.parse(response.body) : {}
        return parsed if response.is_a?(Net::HTTPSuccess)

        raise Error, "Gitea responded #{response.code} for #{path.split('?').first}"
      rescue JSON::ParserError
        raise Error, "Gitea responded with invalid JSON for #{path.split('?').first}"
      end

      def escape(value)
        CGI.escape(value.to_s)
      end

      def escape_path(path)
        path.to_s.split("/").map { |part| CGI.escape(part) }.join("/")
      end
    end
  end
end
