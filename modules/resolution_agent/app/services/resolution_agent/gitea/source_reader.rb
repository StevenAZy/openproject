# frozen_string_literal: true

module ResolutionAgent
  module Gitea
    class SourceReader
      MAX_FILES = 5
      PATH_SCHEMA = {
        type: "object",
        additionalProperties: false,
        required: ["relevant_paths"],
        properties: {
          relevant_paths: { type: "array", items: { type: "string" } }
        }
      }.freeze

      def initialize(setting:, repository_url:, branch:, prompt:)
        @setting = setting
        @repository_url = repository_url
        @branch = branch
        @prompt = prompt
      end

      def call
        repository = Repository.parse(@repository_url, @setting.gitea_base_url)
        return failure(I18n.t("resolution_agent.gitea.wrong_site")) unless repository
        return failure(I18n.t("resolution_agent.gitea.missing_token")) if @setting.gitea_token.blank?

        client = Client.new(repository, token: @setting.gitea_token)
        paths = client.tree_paths(@branch)
        chosen = choose_paths(paths)
        files = chosen.filter_map do |path|
          next if path.blank? || path.include?("..") || path.start_with?("/")
          next unless paths.include?(path)

          body = client.text_file(path, @branch)
          "#{I18n.t('resolution_agent.prompt.file', path:)}\n#{body}" if body.present?
        end
        { ok: true, text: files.join("\n\n") }
      rescue Error => e
        failure(e.message)
      end

      private

      def choose_paths(paths)
        return [] if paths.empty?

        chat = @setting.llm_chat
        chat = chat.with_schema(PATH_SCHEMA) if chat.respond_to?(:with_schema)
        message = chat.ask(
          I18n.t(
            "resolution_agent.prompt.choose_paths",
            branch: @branch,
            limit: MAX_FILES,
            materials: @prompt,
            paths: paths.join("\n")
          )
        )
        content = message.respond_to?(:content) ? message.content : message
        hash = content.is_a?(Hash) ? content : JSON.parse(content.to_s[/\{.*\}/m] || "{}")
        Array(Llm::StructuredOutput.parse!(hash)[:relevant_paths]).first(MAX_FILES)
      end

      def failure(message)
        token = @setting.gitea_token
        text = message.to_s
        text = text.gsub(token, "[redacted]") if token.present?
        { ok: false, error: text }
      end
    end
  end
end
