# frozen_string_literal: true

module ResolutionAgent
  class PanelsController < ApplicationController
    authorization_checked! :show, :message, :decision

    before_action :find_project_by_project_id
    before_action :find_work_package
    before_action :prepare_access

    helper ResolutionAgent::PanelsHelper

    def show
      load_panel
      render layout: false
    end

    def message
      return redirect_to(panel_path) if @denied

      result = Chat.call(
        user: current_user,
        work_package: @work_package,
        body: params[:body],
        gitea_url: params[:gitea_url],
        branch: params[:branch]
      )
      remember_error(result.error)
      redirect_to panel_path
    end

    def decision
      return redirect_to(panel_path) if @denied

      conversation = Conversation.for_work_package(@work_package)
      unless claim(conversation)
        conversation.messages.create!(role: "agent", body: I18n.t("resolution_agent.errors.busy"))
        return redirect_to(panel_path)
      end

      begin
        Decision.call(
          user: current_user,
          work_package: @work_package,
          action: decision_action(conversation),
          assignee_id: params[:assignee_id]
        )
      ensure
        conversation.update!(generating: false)
      end
      redirect_to panel_path
    end

    private

    def find_work_package
      @work_package = @project.work_packages.visible.find(params[:work_package_id])
    end

    def prepare_access
      @setting = Setting.instance
      @access = Access.new(current_user, @work_package, setting: @setting)
      @denied = !@access.open?
    end

    def load_panel
      @conversation = Conversation.find_by(work_package: @work_package)
      @messages = @conversation&.messages&.order(:id) || []
      @runtime_ready = llm_ready?
      @candidates = candidates
    end

    def panel_path
      project_work_package_resolution_agent_path(@project, @work_package)
    end

    def claim(conversation)
      conversation.with_lock do
        if conversation.generating?
          false
        else
          conversation.update!(generating: true)
          true
        end
      end
    end

    def decision_action(conversation)
      action = params[:decision].to_s
      return conversation.pending_action if action == "select_assignee"

      action
    end

    def remember_error(error)
      return if error.blank?

      conversation = Conversation.find_by(work_package: @work_package)
      conversation&.messages&.create!(role: "agent", body: error)
    end

    def llm_ready?
      @setting.enabled? && @setting.llm_ready?
    end

    def candidates
      return [] if @conversation&.pending_assignee_ids.blank?

      Principal.where(id: @conversation.pending_assignee_list)
    end
  end
end
