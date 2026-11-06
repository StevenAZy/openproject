# frozen_string_literal: true

module ResolutionAgent
  class SettingsController < ApplicationController
    layout "admin"
    before_action :require_admin

    menu_item :resolution_agent_settings

    def show
      @setting = Setting.instance
      @project_repositories = ProjectRepository.includes(:project).order("projects.name", :display_name)
      @projects = Project.active.order(:name)
    end

    def update
      setting = Setting.instance
      setting.update!(setting_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to resolution_agent_settings_path
    end

    def test_connection
      result = Gitea::SiteClient.new.test_connection
      AuditEvent.create!(
        actor: current_user,
        action: "gitea.connection_tested",
        result: "success",
        metadata: { version: result[:version], user: result[:user] }
      )
      flash[:notice] = I18n.t("resolution_agent.gitea.connection_ok", version: result[:version], user: result[:user])
      redirect_to resolution_agent_settings_path
    rescue Gitea::ConnectionError => e
      AuditEvent.create!(
        actor: current_user,
        action: "gitea.connection_tested",
        result: "failure",
        metadata: { kind: e.kind }
      )
      flash[:error] = I18n.t("resolution_agent.gitea.connection_errors.#{e.kind}")
      redirect_to resolution_agent_settings_path
    end

    private

    def setting_params
      permitted = params.expect(
        resolution_agent_setting: [
          :enabled,
          :service_account_id,
          :rd_supervisor_id,
          :llm_base_url,
          :llm_api_key,
          :llm_model,
          :gitea_base_url,
          :gitea_token,
          :gitea_webhook_secret,
          :gitea_tls_mode,
          :gitea_custom_ca,
          :status_waiting_rd_id,
          :status_rd_working_id,
          :status_pe_verification_id,
          :status_closed_id,
          { notification_recipient_ids: [] }
        ]
      )
      current = Setting.instance
      permitted[:gitea_token] = current.gitea_token if permitted[:gitea_token].blank?
      permitted[:gitea_webhook_secret] = current.gitea_webhook_secret if permitted[:gitea_webhook_secret].blank?
      permitted[:llm_api_key] = current.llm_api_key if permitted[:llm_api_key].blank?
      permitted
    end
  end
end
