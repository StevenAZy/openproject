# frozen_string_literal: true

module ResolutionAgent
  module Gitea
    class CodeFix
      MAX_FILES = 5

      def initialize(setting:, repository_url:, branch:, work_package:, changes:)
        @setting = setting
        @repository_url = repository_url
        @branch = branch
        @work_package = work_package
        @changes = Array(changes).first(MAX_FILES)
      end

      def call
        repository = Repository.parse(@repository_url, @setting.gitea_base_url)
        return failure(I18n.t("resolution_agent.gitea.wrong_site")) unless repository
        return failure(I18n.t("resolution_agent.gitea.no_changes")) if @changes.empty?
        return failure(I18n.t("resolution_agent.gitea.missing_token")) if @setting.gitea_token.blank?

        client = Client.new(repository, token: @setting.gitea_token)
        fix_branch = "agent/#{@work_package.id}"
        written = false
        @changes.each do |change|
          path = change[:path] || change["path"]
          content = change[:content] || change["content"]
          next if path.blank? || path.include?("..") || path.start_with?("/")

          client.ensure_branch(fix_branch, @branch) unless written
          client.write_file(path, fix_branch, content.to_s, "Fix work package ##{@work_package.id}")
          written = true
        end
        return failure(I18n.t("resolution_agent.gitea.no_changes")) unless written
        url = client.pull_request(
          head: fix_branch,
          base: @branch,
          title: "Fix ##{@work_package.id} #{@work_package.subject}".truncate(70),
          body: "Resolution agent fix for work package ##{@work_package.id}"
        )
        { ok: true, repository: repository.web_base, source_branch: @branch, fix_branch:, pull_request_url: url }
      rescue Error => e
        failure(e.message)
      end

      private

      def failure(message)
        token = @setting.gitea_token
        text = message.to_s
        text = text.gsub(token, "[redacted]") if token.present?
        { ok: false, error: text }
      end
    end
  end
end
