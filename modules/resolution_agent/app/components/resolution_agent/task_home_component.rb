# frozen_string_literal: true

module ResolutionAgent
  class TaskHomeComponent < ApplicationComponent
    PER_PAGE = 20
    FILTERS = %w[all assigned authored processing verification].freeze

    attr_reader :filter, :query, :page

    def initialize(user:, params:)
      super()
      @user = user
      @filter = FILTERS.include?(params[:task_filter]) ? params[:task_filter] : "all"
      @query = params[:task_query].to_s.strip.first(100)
      @page = [params[:task_page].to_i, 1].max
    end

    def tasks
      @tasks ||= filtered_scope
        .includes(:project, :type, :status, :priority, :assigned_to)
        .order(priority_id: :desc, due_date: :asc, updated_at: :desc)
        .offset((page - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .load
    end

    def total_count
      @total_count ||= filtered_scope.count
    end

    def total_pages
      (total_count.to_f / PER_PAGE).ceil
    end

    def filter_path(value, target_page: nil)
      helpers.home_path(task_filter: value, task_query: query.presence, task_page: target_page)
    end

    private

    def filtered_scope
      @filtered_scope ||= begin
        visible = WorkPackage.visible(@user).with_status_open
        assigned = visible.where(assigned_to_id: @user.id)
        authored = visible.where(author_id: @user.id)
        scope = assigned.or(authored)

        scope = case filter
                when "assigned" then scope.where(assigned_to_id: @user.id)
                when "authored" then scope.where(author_id: @user.id)
                when "processing" then scope.where(status_id: settings.status_rd_working_id)
                when "verification"
                  scope.where(author_id: @user.id, status_id: settings.status_pe_verification_id)
                else scope
                end

        if query.present?
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
          scope = scope.where("work_packages.subject ILIKE ?", pattern)
        end

        scope
      end
    end

    def settings
      @settings ||= ResolutionAgent::Setting.instance
    end
  end
end
