# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Conversation do
  shared_let(:work_package) { create(:work_package) }

  subject(:conversation) { described_class.create!(work_package:) }

  describe "generation ownership" do
    it "allows only one current generation" do
      token = conversation.claim_generation!

      expect(token).to be_present
      expect(conversation.reload).to have_attributes(
        generating: true,
        generation_token: token,
        generation_phase: "queued"
      )
      expect(conversation.claim_generation!).to be_nil
    end

    it "does not let an old token update or finish a newer generation" do
      token = conversation.claim_generation!

      expect(conversation.update_generation_phase!("old-token", "generating")).to be false
      expect(conversation.finish_generation!("old-token")).to be false
      expect(conversation.reload).to have_attributes(generating: true, generation_token: token)
    end

    it "recovers an old generation that has no active job" do
      old_token = conversation.claim_generation!
      conversation.update!(generation_started_at: 16.minutes.ago)

      new_token = conversation.claim_generation!

      expect(new_token).to be_present
      expect(new_token).not_to eq(old_token)
      expect(conversation.reload.generation_token).to eq(new_token)
    end

    it "keeps an old generation locked while its job is still active" do
      token = conversation.claim_generation!
      conversation.update!(generation_started_at: 16.minutes.ago, generation_job_id: "active-job")
      job = instance_double(GoodJob::Job, finished_at: nil)
      allow(GoodJob::Job).to receive(:find_by).with(id: "active-job").and_return(job)

      expect(conversation.claim_generation!).to be_nil
      expect(conversation.reload.generation_token).to eq(token)
    end
  end
end
