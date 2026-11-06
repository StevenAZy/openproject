# frozen_string_literal: true

require "set"

module ResolutionAgent
  module Gitea
    class Proposal
      MAX_FILES = 5
      MAX_FILE_BYTES = 100_000
      MAX_TOTAL_BYTES = 300_000
      DENIED_PATHS = [
        ".github/**", ".gitea/**", ".gitlab-ci.yml", ".env*", "**/.env*",
        "Dockerfile*", "**/Dockerfile*", "**/credentials/**", "**/secrets/**",
        "**/*.key", "**/*.pem", "**/CODEOWNERS", "terraform/**", "deploy/**"
      ].freeze

      def initialize(setting:, repository_url:, branch:, changes:)
        @setting = setting
        @repository_url = repository_url
        @branch = branch
        @changes = Array(changes)
      end

      def call
        repository = Repository.parse(@repository_url, @setting.gitea_base_url)
        raise Error, I18n.t("resolution_agent.gitea.wrong_site") unless repository
        raise Error, I18n.t("resolution_agent.gitea.no_changes") if @changes.empty?
        raise Error, I18n.t("resolution_agent.gitea.too_many_files") if @changes.length > MAX_FILES

        client = Client.new(repository, token: @setting.gitea_token)
        allowed_paths = client.tree_paths(@branch, limit: 10_000).to_set
        normalized = @changes.map { |change| normalize_change(change, allowed_paths, client) }
        total_bytes = normalized.sum { |change| change["content"].bytesize }
        raise Error, I18n.t("resolution_agent.gitea.changes_too_large") if total_bytes > MAX_TOTAL_BYTES

        branch = client.branch(@branch)
        {
          changes: normalized,
          source_commit_sha: branch.dig("commit", "id"),
          diff_summary: {
            files: normalized.map { |change| change.except("content") },
            total_bytes:
          }
        }
      end

      private

      def normalize_change(change, allowed_paths, client)
        path = (change[:path] || change["path"]).to_s.tr("\\", "/")
        content = (change[:content] || change["content"]).to_s
        unless allowed_paths.include?(path) && safe_path?(path)
          raise Error, I18n.t("resolution_agent.gitea.path_not_allowed", path:)
        end
        raise Error, I18n.t("resolution_agent.gitea.file_too_large", path:) if content.bytesize > MAX_FILE_BYTES

        original = client.text_file(path, @branch, max_bytes: MAX_FILE_BYTES).to_s
        {
          "path" => path,
          "content" => content,
          "old_bytes" => original.bytesize,
          "new_bytes" => content.bytesize,
          "old_lines" => original.lines.count,
          "new_lines" => content.lines.count
        }
      end

      def safe_path?(path)
        path.present? &&
          !path.start_with?("/") &&
          path.split("/").exclude?("..") &&
          DENIED_PATHS.none? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
      end
    end
  end
end
