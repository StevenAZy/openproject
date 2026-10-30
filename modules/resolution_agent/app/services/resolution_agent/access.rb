# frozen_string_literal: true

module ResolutionAgent
  class Access
    def initialize(user, work_package, setting: Setting.instance)
      @user = user
      @work_package = work_package
      @setting = setting
    end

    def open?
      return false unless @setting.enabled?
      return false unless @work_package.visible?(@user)

      @user.admin? || author? || assignee?
    end

    def author? = @user.id == @work_package.author_id

    def assignee? = @user.id == @work_package.assigned_to_id

    def supervisor?
      @setting.rd_supervisor_id.present? && @user.id == @setting.rd_supervisor_id
    end

    def allowed_decision?(action)
      case action.to_s
      when "pe_resolved", "pe_unresolved", "test_passed", "test_failed" then author?
      when "fix_succeeded", "fix_failed" then assignee?
      when "supervisor_close" then supervisor?
      else false
      end
    end
  end
end
