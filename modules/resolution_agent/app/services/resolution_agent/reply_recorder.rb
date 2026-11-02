# frozen_string_literal: true

module ResolutionAgent
  class ReplyRecorder
    Result = Data.define(:success?, :error, :journal_id)

    def initialize(work_package:, agent:, body:)
      @work_package = work_package
      @agent = agent
      @body = body.to_s.strip
    end

    def call
      return failure(I18n.t("resolution_agent.errors.missing_agent")) if @agent.blank?

      WorkPackage.transaction { persist }
      return failure(@error) if @error

      Result.new(success?: true, error: nil, journal_id: @journal_id)
    end

    private

    def persist
      work_package = WorkPackage.lock.find(@work_package.id)
      result = update(work_package)
      if result.success?
        @journal_id = work_package.journals.reorder(id: :desc).pick(:id)
      else
        @error = result.errors.full_messages.to_sentence
        raise ActiveRecord::Rollback
      end
    end

    def update(work_package)
      User.execute_as(@agent) do
        WorkPackages::UpdateService
          .new(user: @agent, model: work_package)
          .call(description: appended_description(work_package), journal_notes: @body)
      end
    end

    def appended_description(work_package)
      [work_package.description.to_s.rstrip.presence, @body].compact.join("\n\n")
    end

    def failure(error)
      Result.new(success?: false, error:, journal_id: nil)
    end
  end
end
