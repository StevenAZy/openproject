# frozen_string_literal: true

module ResolutionAgent
  class SettingsController < ApplicationController
    layout "admin"
    before_action :require_admin

    menu_item :resolution_agent_settings

    def show
      @setting = Setting.instance
      @users = User.not_locked.where(type: "User").order(:lastname, :firstname)
    end

    def update
      setting = Setting.instance
      setting.update!(setting_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to resolution_agent_settings_path
    end

    private

    def setting_params
      permitted = params.expect(resolution_agent_setting: %i[
                                  enabled service_account_id rd_supervisor_id
                                  llm_base_url llm_api_key llm_model gitea_base_url gitea_token
                                ])
      current = Setting.instance
      permitted[:gitea_token] = current.gitea_token if permitted[:gitea_token].blank?
      permitted[:llm_api_key] = current.llm_api_key if permitted[:llm_api_key].blank?
      permitted
    end
  end
end
