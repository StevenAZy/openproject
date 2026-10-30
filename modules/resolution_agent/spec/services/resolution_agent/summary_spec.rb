# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Summary do
  it "uses the fixed headings and fills missing facts" do
    text = described_class.build({})

    expect(text).to include("#{I18n.t('resolution_agent.summary.conclusion')}\n#{I18n.t('resolution_agent.summary.missing')}")
    expect(text).to include("#{I18n.t('resolution_agent.summary.environment')}\n#{I18n.t('resolution_agent.summary.missing')}")
    expect(text).to include("#{I18n.t('resolution_agent.summary.problem')}\n#{I18n.t('resolution_agent.summary.missing')}")
    expect(text).to include("#{I18n.t('resolution_agent.summary.attempts')}\n#{I18n.t('resolution_agent.summary.missing')}")
    expect(text).to include("#{I18n.t('resolution_agent.summary.log_reading')}\n#{I18n.t('resolution_agent.summary.no_log')}")
    expect(text).to include("#{I18n.t('resolution_agent.summary.direction')}\n#{I18n.t('resolution_agent.summary.missing')}")
    expect(text).not_to include(I18n.t("resolution_agent.summary.original"))
  end

  it "keeps the previous description only when rewriting" do
    text = described_class.build({ conclusion: "未解决并转交 R&D" }, original: "旧描述")

    expect(text).to include("#{I18n.t('resolution_agent.summary.conclusion')}\n未解决并转交 R&D")
    expect(text).to end_with("#{I18n.t('resolution_agent.summary.original')}\n旧描述")
  end
end
