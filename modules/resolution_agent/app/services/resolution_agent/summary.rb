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
      lines = SECTIONS.map { |key| section(key) }
      lines << "#{I18n.t("resolution_agent.summary.original")}\n#{@original}" if @original
      lines.join("\n\n")
    end

    private

    def section(key)
      value = @fields[key].to_s.strip
      missing = I18n.t("resolution_agent.summary.missing")
      value = missing if value.blank?
      value = I18n.t("resolution_agent.summary.no_log") if key == :log_reading && value == missing
      "#{I18n.t("resolution_agent.summary.#{key}")}\n#{value}"
    end
  end
end
