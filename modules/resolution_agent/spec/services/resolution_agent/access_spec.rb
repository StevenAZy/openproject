# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Access do
  let(:setting) { double(enabled?: true, rd_supervisor_id: 9) }
  let(:work_package) { instance_double(WorkPackage, visible?: true, author_id: 1, assigned_to_id: 2) }

  def access_for(id, admin: false)
    user = instance_double(User, id:, admin?: admin)
    described_class.new(user, work_package, setting:)
  end

  it "opens for the author and the current assignee" do
    expect(access_for(1)).to be_open
    expect(access_for(2)).to be_open
  end

  it "stays closed for someone else" do
    expect(access_for(5)).not_to be_open
  end

  it "lets an administrator who can view the work package open it" do
    expect(access_for(8, admin: true)).to be_open
  end

  it "does not open a work package the user cannot view" do
    hidden = instance_double(WorkPackage, visible?: false, author_id: 1, assigned_to_id: 2)
    user = instance_double(User, id: 1, admin?: true)

    expect(described_class.new(user, hidden, setting:)).not_to be_open
  end

  it "keeps outcome actions with the person who owns them" do
    author = access_for(1)
    assignee = access_for(2)
    supervisor = access_for(9)

    expect(author.allowed_decision?("pe_resolved")).to be true
    expect(author.allowed_decision?("test_passed")).to be true
    expect(assignee.allowed_decision?("pe_resolved")).to be false
    expect(assignee.allowed_decision?("fix_succeeded")).to be true
    expect(assignee.allowed_decision?("fix_failed")).to be true
    expect(supervisor.allowed_decision?("supervisor_close")).to be true
    expect(author.allowed_decision?("supervisor_close")).to be false
  end
end
