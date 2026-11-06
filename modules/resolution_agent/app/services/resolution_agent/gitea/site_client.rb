# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"
require "uri"
require "cgi"

module ResolutionAgent
  module Gitea
    class SiteClient
      def initialize(setting = Setting.instance)
        @setting = setting
        @base_uri = URI(setting.gitea_base_url.to_s)
      end

      def test_connection
        version = request("/version")
        user = request("/user")
        { version: version["version"], user: user["login"] }
      end

      def repository(owner, name)
        request("/repos/#{escape(owner)}/#{escape(name)}")
      end

      def branches(owner, name)
        request("/repos/#{escape(owner)}/#{escape(name)}/branches?limit=100").map { |branch| branch["name"] }
      end

      private

      def request(path)
        uri = api_uri(path)
        response = http_for(uri).request(request_for(uri))
        parsed = response.body.present? ? JSON.parse(response.body) : {}
        return parsed if response.is_a?(Net::HTTPSuccess)

        kind = case response.code.to_i
               when 401 then :authentication_failed
               when 403 then :permission_denied
               when 404 then :api_not_found
               else :gitea_error
               end
        raise ConnectionError.new(kind, "Gitea responded #{response.code}")
      rescue SocketError => e
        raise ConnectionError.new(:dns_failure, e.message)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise ConnectionError.new(:connect_timeout, e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise ConnectionError.new(:tls_failure, e.message)
      rescue JSON::ParserError => e
        raise ConnectionError.new(:invalid_response, e.message)
      end

      def api_uri(path)
        base_path = @base_uri.path.to_s.sub(%r{/+\z}, "")
        @base_uri.dup.tap do |uri|
          uri.path = "#{base_path}/api/v1#{path}"
          uri.query = nil
          if path.include?("?")
            uri.path, uri.query = uri.path.split("?", 2)
          end
        end
      end

      def http_for(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = 20
          configure_certificate_store(http) if http.use_ssl?
        end
      end

      def configure_certificate_store(http)
        return unless @setting.gitea_tls_mode == "custom_ca" && @setting.gitea_custom_ca.present?

        store = OpenSSL::X509::Store.new
        store.set_default_paths
        store.add_cert(OpenSSL::X509::Certificate.new(@setting.gitea_custom_ca))
        http.cert_store = store
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      def request_for(uri)
        Net::HTTP::Get.new(uri).tap do |request|
          request["Authorization"] = "token #{@setting.gitea_token}"
          request["Accept"] = "application/json"
        end
      end

      def escape(value)
        CGI.escape(value.to_s)
      end
    end
  end
end
