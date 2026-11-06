# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Stage do
  Run = Struct.new(:id, :outcome, :pull_request_url, :assignee_before_fix_id)

  def stage(*runs)
    described_class.new(runs.map { |attrs| Run.new(*attrs) })
  end

  it "starts in collection and only offers the field conclusions" do
    current = stage()

    expect(current.name).to eq("collecting")
    expect(current.allowed_actions).to eq(%w[pe_resolved pe_unresolved])
    expect(current.code_entry?).to be false
  end

  it "hides fix outcomes until this handoff has a code attempt" do
    handed = stage([1, "pe_resolved", nil, nil])

    expect(handed.name).to eq("with_rd")
    expect(handed.allowed_actions).to eq([])

    attempted = stage(
      [1, "pe_resolved", nil, nil],
      [2, "gitea_failed", nil, 4]
    )
    expect(attempted.allowed_actions).to eq(["fix_failed"])
    expect(attempted.assignee_before_fix_id).to eq(4)

    opened = stage(
      [1, "pe_resolved", nil, nil],
      [2, "gitea_attempt", "https://gitea.example/pulls/1", 4]
    )
    expect(opened.allowed_actions).to eq(%w[fix_succeeded fix_failed])
  end

  it "ignores a pull request opened before the current stage" do
    current = stage(
      [1, "gitea_attempt", "https://gitea.example/pulls/1", 4],
      [2, "pe_resolved", nil, nil]
    )

    expect(current.allowed_actions).to eq([])
  end

  it "moves to testing after a successful fix and back when the latest test fails" do
    testing = stage(
      [1, "pe_unresolved", nil, nil],
      [2, "gitea_attempt", "https://gitea.example/pulls/1", 4],
      [3, "fix_succeeded", nil, nil]
    )
    expect(testing.name).to eq("in_testing")
    expect(testing.allowed_actions).to eq(%w[test_passed test_failed])

    failed = stage(
      [1, "pe_unresolved", nil, nil],
      [2, "fix_succeeded", nil, nil],
      [3, "test_passed", nil, nil],
      [4, "test_failed", nil, nil]
    )
    expect(failed.name).to eq("testing_failed")
    expect(failed.allowed_actions).to eq(%w[test_passed test_failed])
    expect(failed.latest_test_passed?).to be false
  end

  it "closes after the PE confirms the latest test passed" do
    closed = stage(
      [1, "fix_succeeded", nil, nil],
      [2, "test_failed", nil, nil],
      [3, "test_passed", nil, nil]
    )

    expect(closed.name).to eq("closed")
    expect(closed.allowed_actions).to eq([])
    expect(closed.latest_test_passed?).to be true
  end

  it "returns to research and development after a failed fix" do
    returned = stage(
      [1, "pe_resolved", nil, nil],
      [2, "gitea_attempt", "https://gitea.example/pulls/1", 4],
      [3, "fix_failed", nil, nil]
    )

    expect(returned.name).to eq("with_rd")
    expect(returned.allowed_actions).to eq([])
  end
end
