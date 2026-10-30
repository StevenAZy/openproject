# frozen_string_literal: true

module ResolutionAgent
  class Summary
    SECTIONS = %i[conclusion environment problem attempts log_reading direction].freeze

    def self.build(fields, original: nil)
      new(fields, original:).to_s
    end

    def initialize(fields, original: nil)
      @fields = fields.to_h.symbolize_keys
      @original = original
    end

    def to_s
      lines = [
        section("当前结论", :conclusion),
        section("环境", :environment),
        section("问题", :problem),
        section("已做尝试", :attempts),
        section("日志解读", :log_reading),
        section("代理给出的方向", :direction)
      ]
      lines << "原始记录\n#{@original}" if @original
      lines.join("\n\n")
    end

    private

    def section(title, key)
      value = @fields[key].to_s.strip
      value = "未提供" if value.blank?
      value = "无日志附件" if key == :log_reading && value == "未提供"
      "#{title}\n#{value}"
    end
  end
end
