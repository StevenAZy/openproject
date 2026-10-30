# frozen_string_literal: true

module ResolutionAgent
  class WorkPackageChange
    def initialize(work_package, agent:)
      @work_package = work_package
      @agent = agent
    end

    def call(attributes:, summary:)
      error = nil
      journal_id = nil

      WorkPackage.transaction do
        work_package = WorkPackage.lock.find(@work_package.id)
        result = User.execute_as(@agent) do
          WorkPackages::UpdateService
            .new(user: @agent, model: work_package)
            .call(attributes.merge(journal_notes: summary))
        end
        if result.success?
          journal_id = work_package.journals.reorder(id: :desc).pick(:id)
        else
          error = result.errors.full_messages.to_sentence
          raise ActiveRecord::Rollback
        end
      end

      error.nil? ? [:ok, journal_id] : [:error, error]
    end
  end
end
