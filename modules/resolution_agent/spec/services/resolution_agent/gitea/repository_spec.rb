# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Gitea::Repository do
  let(:base_url) { "https://git.example.com" }

  it "accepts a repository on the configured site" do
    repository = described_class.parse("https://git.example.com/acme/device.git", base_url)

    expect(repository.owner).to eq("acme")
    expect(repository.name).to eq("device")
    expect(repository.api_base).to eq("https://git.example.com/api/v1/repos/acme/device")
    expect(repository.web_base).to eq("https://git.example.com/acme/device")
  end

  it "rejects a repository on another site" do
    expect(described_class.parse("https://other.example.com/acme/device", base_url)).to be_nil
  end

  it "keeps a non-default port" do
    repository = described_class.parse("https://git.example.com:3000/acme/device", "https://git.example.com:3000")

    expect(repository.api_base).to eq("https://git.example.com:3000/api/v1/repos/acme/device")
  end
end
