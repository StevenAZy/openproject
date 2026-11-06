# frozen_string_literal: true

namespace :resolution_agent do
  namespace :product do
    desc "Validate Task Agent data compatibility and print a JSON report"
    task validate: :environment do
      connection = ActiveRecord::Base.connection
      tables = %w[
        projects work_packages journals relations attachments
        resolution_agent_conversations resolution_agent_messages resolution_agent_runs
        resolution_agent_project_repositories resolution_agent_fix_attempts
        resolution_agent_webhook_events resolution_agent_audit_events
      ]
      counts = tables.index_with do |table|
        connection.data_source_exists?(table) ? connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}") : nil
      end
      checks = {
        orphan_work_packages: WorkPackage.where.missing(:project).count,
        orphan_conversations: ResolutionAgent::Conversation.where.missing(:work_package).count,
        orphan_fix_attempts: ResolutionAgent::FixAttempt.where.missing(:work_package).count,
        historical_parents: WorkPackage.where.not(parent_id: nil).count,
        archived_relations: Relation.count
      }

      puts JSON.pretty_generate(counts:, checks:, generated_at: Time.current.iso8601)
      abort "Task Agent validation failed: orphaned records found" if checks.values_at(
        :orphan_work_packages,
        :orphan_conversations,
        :orphan_fix_attempts
      ).any?(&:positive?)
    end

    desc "Diagnose required Task Agent workflow settings"
    task diagnose_workflow: :environment do
      setting = ResolutionAgent::Setting.instance
      statuses = %i[
        status_waiting_rd_id status_rd_working_id status_pe_verification_id status_closed_id
      ].to_h { |attribute| [attribute, Status.find_by(id: setting.public_send(attribute))&.name] }
      report = {
        service_account: setting.service_account&.name,
        statuses:,
        pe_role_present: Role.exists?(name: "PE"),
        rd_role_present: Role.exists?(name: "R&D")
      }
      puts JSON.pretty_generate(report)
      abort "Task Agent workflow configuration is incomplete" if report[:service_account].blank? ||
        statuses.value?(nil) ||
        !report[:pe_role_present] ||
        !report[:rd_role_present]
    end
  end
end
