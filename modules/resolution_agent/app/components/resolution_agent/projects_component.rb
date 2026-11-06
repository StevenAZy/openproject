# frozen_string_literal: true

module ResolutionAgent
  class ProjectsComponent < ApplicationComponent
    PER_PAGE = 20

    attr_reader :page, :query

    def initialize(user:, params:)
      super()
      @user = user
      @query = params[:project_query].to_s.strip.first(100)
      @page = [params[:project_page].to_i, 1].max
    end

    def projects
      @projects ||= project_scope
        .order(updated_at: :desc)
        .offset((page - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .load
    end

    def task_count(project)
      task_counts.fetch(project.id, 0)
    end

    def can_create_project?
      @user.allowed_globally?(:add_project)
    end

    def total_pages
      (project_scope.count.to_f / PER_PAGE).ceil
    end

    def page_path(target_page)
      helpers.projects_path(project_query: query.presence, project_page: target_page)
    end

    private

    def project_scope
      @project_scope ||= begin
        scope = Project.visible(@user).active
        if query.present?
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
          scope = scope.where("projects.name ILIKE ?", pattern)
        end
        scope
      end
    end

    def task_counts
      @task_counts ||= begin
        visible = WorkPackage.visible(@user).with_status_open.where(project_id: projects.map(&:id))
        assigned = visible.where(assigned_to_id: @user.id)
        authored = visible.where(author_id: @user.id)
        assigned.or(authored).group(:project_id).count
      end
    end
  end
end
