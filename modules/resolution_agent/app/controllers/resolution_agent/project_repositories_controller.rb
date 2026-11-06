# frozen_string_literal: true

module ResolutionAgent
  class ProjectRepositoriesController < ApplicationController
    layout "admin"
    before_action :require_admin

    def create
      project = Project.find(repository_params[:project_id])
      remote = Gitea::SiteClient.new.repository(repository_params[:owner], repository_params[:name])
      repository = ProjectRepository.new(
        project:,
        gitea_repository_id: remote["id"],
        owner: remote.dig("owner", "login") || repository_params[:owner],
        name: remote["name"] || repository_params[:name],
        display_name: repository_params[:display_name].presence || remote["full_name"],
        default_branch: repository_params[:default_branch].presence || remote["default_branch"],
        created_by: current_user,
        updated_by: current_user
      )
      repository.save!
      AuditEvent.create!(
        actor: current_user,
        project:,
        project_repository: repository,
        action: "repository.mapped",
        result: "success",
        metadata: { repository: repository.full_name }
      )
      flash[:notice] = I18n.t(:notice_successful_create)
    rescue Gitea::ConnectionError => e
      flash[:error] = I18n.t("resolution_agent.gitea.connection_errors.#{e.kind}")
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.record.errors.full_messages.to_sentence
    ensure
      redirect_to resolution_agent_settings_path
    end

    def destroy
      repository = ProjectRepository.find(params[:id])
      repository.update!(active: false, updated_by: current_user)
      AuditEvent.create!(
        actor: current_user,
        project: repository.project,
        project_repository: repository,
        action: "repository.unmapped",
        result: "success",
        metadata: { repository: repository.full_name }
      )
      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to resolution_agent_settings_path
    end

    private

    def repository_params
      params.expect(resolution_agent_project_repository: %i[
                      project_id owner name display_name default_branch
                    ])
    end
  end
end
