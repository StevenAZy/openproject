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
        return failure("仓库不属于已配置的 Gitea 站点") unless repository
        return failure("Gitea 令牌未配置") if @setting.gitea_token.blank?

        client = Client.new(repository, token: @setting.gitea_token)
        paths = client.tree_paths(@branch)
        chosen = choose_paths(paths)
        files = chosen.filter_map do |path|
          next if path.blank? || path.include?("..") || path.start_with?("/")
          next unless paths.include?(path)

          body = client.text_file(path, @branch)
          "文件 #{path}\n#{body}" if body.present?
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
        message = chat.ask(<<~PROMPT)
          下面是仓库分支 #{@branch} 的文件路径。选出和这段材料最相关的最多 #{MAX_FILES} 个文件路径，不要编造列表里没有的路径。
          材料:
          #{@prompt}
          路径:
          #{paths.join("\n")}
        PROMPT
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
