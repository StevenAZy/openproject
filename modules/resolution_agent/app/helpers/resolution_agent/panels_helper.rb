# frozen_string_literal: true

module ResolutionAgent
  module PanelsHelper
    def decision_buttons
      buttons = []
      if @access.author?
        buttons << ["pe_resolved", t("resolution_agent.actions.pe_resolved")]
        buttons << ["pe_unresolved", t("resolution_agent.actions.pe_unresolved")]
        buttons << ["test_passed", t("resolution_agent.actions.test_passed")]
        buttons << ["test_failed", t("resolution_agent.actions.test_failed")]
      end
      if @access.assignee?
        buttons << ["fix_succeeded", t("resolution_agent.actions.fix_succeeded")]
        buttons << ["fix_failed", t("resolution_agent.actions.fix_failed")]
      end
      buttons << ["supervisor_close", t("resolution_agent.actions.supervisor_close")] if @access.supervisor?
      buttons
    end
  end
end
