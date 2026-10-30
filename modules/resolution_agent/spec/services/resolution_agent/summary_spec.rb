# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Summary do
  it "uses the fixed headings and fills missing facts" do
    text = described_class.build({})

    expect(text).to include("当前结论\n未提供")
    expect(text).to include("环境\n未提供")
    expect(text).to include("问题\n未提供")
    expect(text).to include("已做尝试\n未提供")
    expect(text).to include("日志解读\n无日志附件")
    expect(text).to include("代理给出的方向\n未提供")
    expect(text).not_to include("原始记录")
  end

  it "keeps the previous description only when rewriting" do
    text = described_class.build({ conclusion: "未解决并转交 R&D" }, original: "旧描述")

    expect(text).to include("当前结论\n未解决并转交 R&D")
    expect(text).to end_with("原始记录\n旧描述")
  end
end
