# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::GenerateReplyJob do
  include ActiveJob::TestHelper

  shared_let(:user) { create(:user) }
  shared_let(:work_package) { create(:work_package, author: user) }

  let(:conversation) { ResolutionAgent::Conversation.create!(work_package:) }
  let(:token) { conversation.claim_generation! }
  let(:chat) { instance_double(ResolutionAgent::Chat) }
  let(:arguments) do
    {
      user:,
      work_package:,
      conversation_id: conversation.id,
      token:,
      body: "Investigate",
      gitea_url: nil,
      branch: nil
    }
  end

  before do
    User.current = user
    allow(ResolutionAgent::Chat).to receive(:new).and_return(chat)
  end

  it "updates progress, stores the result, and releases the generation" do
    allow(chat).to receive(:generate) do |conversation:, token:, on_phase:|
      on_phase.call("generating")
      conversation.messages.create!(role: "agent", body: "Done") if conversation.generation_current?(token)
    end

    described_class.perform_now(**arguments)

    expect(conversation.reload).not_to be_generating
    expect(conversation.messages.last).to have_attributes(role: "agent", body: "Done")
  end

  it "classifies model timeouts and releases the generation" do
    allow(chat).to receive(:generate).and_raise(Llm::Errors::TimeoutError, "timed out")

    described_class.perform_now(**arguments)

    expect(conversation.reload).not_to be_generating
    expect(conversation.messages.last).to have_attributes(
      role: "notice",
      body: I18n.t("resolution_agent.errors.timeout")
    )
  end
end
