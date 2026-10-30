# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::AssigneeResolver do
  let(:supervisor) { instance_double(User, id: 7, name: "主管") }
  let(:first_assignee) { instance_double(User, id: 3, name: "甲") }
  let(:second_assignee) { instance_double(User, id: 4, name: "乙") }

  it "hands the first issue to the configured supervisor" do
    result = described_class.choose(related_present: false, assignees: [], supervisor:)

    expect(result).to be_ok
    expect(result.assignees).to eq([supervisor])
  end

  it "does not invent a supervisor" do
    result = described_class.choose(related_present: false, assignees: [], supervisor: nil)

    expect(result.status).to eq(:missing_supervisor)
  end

  it "uses the single related assignee" do
    result = described_class.choose(related_present: true, assignees: [first_assignee], supervisor:)

    expect(result.assignees).to eq([first_assignee])
  end

  it "asks for a choice when related assignees differ" do
    result = described_class.choose(related_present: true, assignees: [first_assignee, second_assignee], supervisor:)

    expect(result).to be_choose
    expect(result.assignees).to eq([first_assignee, second_assignee])
  end

  it "does not fall back to the supervisor when related work packages have no assignee" do
    result = described_class.choose(related_present: true, assignees: [], supervisor:)

    expect(result.status).to eq(:related_without_assignee)
  end

  it "ignores predecessor and follower relations" do
    expect(described_class::RELATED_TYPES).not_to include("precedes", "follows")
  end
end
