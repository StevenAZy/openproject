# frozen_string_literal: true

module ResolutionAgent
  class AssigneeResolver
    RELATED_TYPES = %w[relates blocks blocked duplicates duplicated includes partof requires required].freeze

    Result = Data.define(:status, :assignees) do
      def ok? = status == :ok

      def choose? = status == :choose
    end

    def self.choose(related_present:, assignees:, supervisor:)
      unique = Array(assignees).compact.uniq
      if related_present
        return Result.new(status: :related_without_assignee, assignees: []) if unique.empty?
        return Result.new(status: :choose, assignees: unique) if unique.size > 1

        Result.new(status: :ok, assignees: unique)
      elsif supervisor.present?
        Result.new(status: :ok, assignees: [supervisor])
      else
        Result.new(status: :missing_supervisor, assignees: [])
      end
    end

    def initialize(work_package, user:, supervisor:)
      @work_package = work_package
      @user = user
      @supervisor = supervisor
    end

    def call
      related = related_work_packages
      self.class.choose(
        related_present: related.any?,
        assignees: related.filter_map(&:assigned_to),
        supervisor: @supervisor
      )
    end

    private

    def related_work_packages
      ids = relative_ids
      return [] if ids.empty?

      WorkPackage.visible(@user).where(id: ids).to_a
    end

    def relative_ids
      ids = []
      ids << @work_package.parent_id if @work_package.parent_id
      ids.concat(@work_package.children.pluck(:id))
      relations = Relation.where(relation_type: RELATED_TYPES)
                          .where("from_id = :id OR to_id = :id", id: @work_package.id)
      relations.each do |relation|
        ids << (relation.from_id == @work_package.id ? relation.to_id : relation.from_id)
      end
      ids.compact.uniq - [@work_package.id]
    end
  end
end
