# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::ReplyRecorder do
  shared_let(:agent) { create(:user) }
  shared_let(:work_package) { create(:work_package, description: "Existing description") }

  let(:update_service) { instance_double(WorkPackages::UpdateService) }
  let(:service_result) { instance_double(ServiceResult, success?: true) }

  before do
    allow(WorkPackages::UpdateService).to receive(:new).and_return(update_service)
    allow(update_service).to receive(:call).and_return(service_result)
  end

  subject(:call) do
    described_class.new(work_package:, agent:, body: "Agent answer").call
  end

  it "appends the answer to the description and adds the same activity comment" do
    expect(call).to be_success
    expect(update_service).to have_received(:call).with(
      description: "Existing description\n\nAgent answer",
      journal_notes: "Agent answer"
    )
  end

  it "fails without changing the work package when no service account is configured" do
    result = described_class.new(work_package:, agent: nil, body: "Agent answer").call

    expect(result).not_to be_success
    expect(update_service).not_to have_received(:call)
  end
end
