# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Chat do
  shared_let(:user) { create(:user) }
  shared_let(:work_package) { create(:work_package, author: user) }

  let(:access) { instance_double(ResolutionAgent::Access, open?: true) }
  let(:job) { instance_double(ResolutionAgent::GenerateReplyJob, job_id: "agent-job") }

  before do
    allow(ResolutionAgent::Access).to receive(:new).and_return(access)
    allow(ResolutionAgent::GenerateReplyJob).to receive(:perform_later).and_return(job)
  end

  subject(:call) { described_class.call(user:, work_package:, body: "Please investigate") }

  it "stores the user message, claims the conversation, and queues the reply" do
    expect(call).to be_success
    expect(call.job_id).to eq("agent-job")

    conversation = ResolutionAgent::Conversation.find_by!(work_package:)
    expect(conversation.messages.pluck(:role, :body, :user_id))
      .to contain_exactly(["user", "Please investigate", user.id])
    expect(conversation).to have_attributes(
      generating: true,
      generation_job_id: "agent-job",
      generation_phase: "queued"
    )
    expect(ResolutionAgent::GenerateReplyJob).to have_received(:perform_later).once
  end

  it "does not queue a second reply while one is current" do
    conversation = ResolutionAgent::Conversation.for_work_package(work_package)
    conversation.claim_generation!

    expect(call).not_to be_success
    expect(call.error).to eq(I18n.t("resolution_agent.errors.busy"))
    expect(ResolutionAgent::GenerateReplyJob).not_to have_received(:perform_later)
  end

  it "rolls back the message and generation lock when enqueueing fails" do
    allow(ResolutionAgent::GenerateReplyJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError)

    expect(call).not_to be_success

    conversation = ResolutionAgent::Conversation.find_by!(work_package:)
    expect(conversation.reload).not_to be_generating
    expect(conversation.messages).to be_empty
  end
end
