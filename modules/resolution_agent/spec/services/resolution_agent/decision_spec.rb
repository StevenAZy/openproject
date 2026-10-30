# frozen_string_literal: true

require "spec_helper"

RSpec.describe ResolutionAgent::Decision do
  describe ".phrase" do
    it "matches the outcome phrases exactly" do
      expect(described_class.phrase("已解决")).to eq("pe_resolved")
      expect(described_class.phrase(" 方案无效 ")).to eq("pe_unresolved")
      expect(described_class.phrase("修复有效")).to eq("fix_succeeded")
      expect(described_class.phrase("修复失败")).to eq("fix_failed")
      expect(described_class.phrase("测试通过")).to eq("test_passed")
      expect(described_class.phrase("测试未通过")).to eq("test_failed")
      expect(described_class.phrase("确认完成")).to eq("supervisor_close")
    end

    it "does not treat a longer message as an outcome" do
      expect(described_class.phrase("测试通过，复测正常")).to be_nil
    end
  end
end
