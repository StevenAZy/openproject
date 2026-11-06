# frozen_string_literal: true

module ResolutionAgent
  module ProductGuard
    extend ActiveSupport::Concern

    REMOVED_CONTROLLER_PREFIXES = %w[
      activities
      backlogs
      boards
      budgets
      calendars
      cost_reports
      documents
      forums
      gantt
      ifc_models
      meetings
      news
      placeholder_users
      portfolios
      programs
      repositories
      resource_management
      storages
      team_planner
      time_entries
      versions
      wiki
      wikis
    ].freeze

    included do
      before_action :deny_removed_product_feature
    end

    private

    def deny_removed_product_feature
      return unless REMOVED_CONTROLLER_PREFIXES.any? { |prefix| controller_path.start_with?(prefix) }

      render_404
    end
  end
end
