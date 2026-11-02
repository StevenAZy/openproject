# frozen_string_literal: true

module ResolutionAgent
  class PanelsController < ApplicationController
    authorization_checked! :show, :message, :decision, :status

    before_action :find_project_by_project_id
    before_action :find_work_package
    before_action :prepare_access

    helper ResolutionAgent::PanelsHelper

    def show
      load_panel
      render layout: false
    end

    def status
      load_panel
      return head :not_found unless valid_job_status?

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "resolution-agent-tab-content",
            template: "resolution_agent/panels/show"
          )
        end
        format.html { redirect_to panel_path }
      end
    end

    def message
      return redirect_to(panel_path, status: :see_other) if @denied

      result = Chat.call(
        user: current_user,
        work_package: @work_package,
        body: params[:body],
        gitea_url: params[:gitea_url],
        branch: params[:branch]
      )
      flash[:error] = result.error if result.error.present?
      redirect_to panel_path, status: :see_other
    end

    def decision
      return redirect_to(panel_path, status: :see_other) if @denied

      conversation = Conversation.for_work_package(@work_package)
      unless claim(conversation)
        conversation.messages.create!(role: "notice", body: I18n.t("resolution_agent.errors.busy"))
        return redirect_to(panel_path, status: :see_other)
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
      redirect_to panel_path, status: :see_other
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
      @conversation&.recover_stale_generation!
      @messages = @conversation&.messages&.includes(:user)&.order(:id) || Message.none
      @stage = Stage.new(@conversation&.runs&.to_a || [])
      @runtime_ready = llm_ready?
      @candidates = candidates
      @polled_job_finished = action_name == "status" && !@conversation&.generating? && known_generation_job?
    end

    def valid_job_status?
      !@denied && known_generation_job?
    end

    def known_generation_job?
      params[:job].present? && @conversation&.generation_job_id == params[:job]
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

    def llm_ready?
      @setting.enabled? && @setting.llm_ready?
    end

    def candidates
      return [] unless @access.author?
      return [] if @conversation&.pending_assignee_ids.blank?

      ids = @conversation.pending_assignee_list.map(&:to_i)
      Principal.where(id: ids).index_by(&:id).values_at(*ids).compact
    end
  end
end
