# frozen_string_literal: true

module ResolutionAgent
  class Context
    TEXT_EXTENSIONS = %w[.txt .md .markdown .csv .json .log].freeze
    SKIPPED_EXTENSIONS = %w[.zip .gz .tgz .7z .rar .doc .docx .xls .xlsx .ppt .pptx .mp3 .mp4 .wav .mov .avi].freeze
    MAX_FILES = 10
    MAX_BYTES = 100_000

    Snapshot = Data.define(:id, :type_name, :assignee_name)

    def initialize(work_package, user:, vision: false)
      @work_package = work_package
      @user = user
      @vision = vision
    end

    def prompt
      [
        work_package_section,
        comments_section,
        custom_fields_section,
        attachments_section,
        file_links_section
      ].join("\n\n")
    end

    def attachment_names
      attachment_entries.map { |entry| entry[:name] }
    end

    def image_paths
      return [] unless @vision

      attachment_entries.filter_map { |entry| entry[:path] if entry[:image] }
    end

    def related_snapshots
      AssigneeResolver.new(@work_package, user: @user, supervisor: nil)
                      .send(:related_work_packages)
                      .map { |work_package| Snapshot.new(id: work_package.id, type_name: work_package.type&.name, assignee_name: work_package.assigned_to&.name) }
    end

    private

    def work_package_section
      wp = @work_package
      <<~TEXT.strip
        工作包 ##{wp.id}
        标题: #{wp.subject}
        状态: #{wp.status&.name}
        类型: #{wp.type&.name}
        优先级: #{wp.priority&.name}
        负责人: #{wp.assigned_to&.name || "未提供"}
        描述:
        #{wp.description.presence || "未提供"}
      TEXT
    end

    def comments_section
      notes = @work_package.journals.where.not(notes: [nil, ""]).reorder(id: :desc).limit(20).reverse
      return "评论: 未提供" if notes.empty?

      body = notes.map { |journal| "#{journal.user&.name}: #{journal.notes}" }.join("\n")
      "最近评论:\n#{body}"
    end

    def custom_fields_section
      values = @work_package.custom_field_values.select { |value| value.custom_field.field_format == "text" && value.value.present? }
      return "长文本字段: 未提供" if values.empty?

      values.map { |value| "#{value.custom_field.name}: #{value.value}" }.join("\n")
    end

    def attachments_section
      entries = attachment_entries
      return "附件: 无日志附件" if entries.empty?

      entries.map { |entry| attachment_line(entry) }.join("\n\n")
    end

    def file_links_section
      links = @work_package.file_links.includes(:storage)
      return "外部文件: 未提供" if links.none?

      lines = links.map do |link|
        "文件名: #{link.name} 存储: #{link.storage&.name} 路径: 未提供"
      end
      "外部文件元数据（没有正文，不要写入日志解读）:\n#{lines.join("\n")}"
    end

    def attachment_entries
      @attachment_entries ||= begin
        remaining = MAX_FILES
        @work_package.attachments.map do |attachment|
          if remaining.positive? && body_candidate?(attachment)
            remaining -= 1
            read_attachment(attachment)
          else
            listed_attachment(attachment)
          end
        end
      end
    end

    def body_candidate?(attachment)
      extension = File.extname(attachment.filename.to_s).downcase
      return false if SKIPPED_EXTENSIONS.include?(extension)
      return true if extension == ".pdf" || attachment.content_type == "application/pdf"
      return true if @vision && attachment.content_type.to_s.start_with?("image/")

      text_attachment?(attachment, extension)
    end

    def listed_attachment(attachment)
      { name: attachment.filename.to_s, meta: meta_line(attachment), body: nil, image: false, path: nil, note: "仅列出文件名" }
    end

    def read_attachment(attachment)
      name = attachment.filename.to_s
      extension = File.extname(name).downcase
      entry = listed_attachment(attachment).merge(note: nil)
      if SKIPPED_EXTENSIONS.include?(extension)
        entry[:note] = "仅列出文件名"
      elsif extension == ".pdf" || attachment.content_type == "application/pdf"
        entry[:body] = pdf_text(attachment)
        entry[:note] = "无文本层" if entry[:body].blank?
      elsif attachment.content_type.to_s.start_with?("image/")
        entry[:image] = true
        entry[:path] = file_path(attachment) if @vision
        entry[:note] = "仅列出文件名" unless @vision && entry[:path]
      elsif text_attachment?(attachment, extension)
        entry[:body] = text_body(attachment)
        entry[:note] = "无法读取" if entry[:body].blank?
      else
        entry[:note] = "仅列出文件名"
      end
      entry
    rescue StandardError
      listed_attachment(attachment).merge(note: "无法读取")
    end

    def meta_line(attachment)
      "大小: #{attachment.filesize} 类型: #{attachment.content_type.presence || "未提供"} 上传者: #{attachment.author&.name || "未提供"} 时间: #{attachment.created_at}"
    end

    def file_path(attachment)
      path = attachment.local_path
      path if path && File.readable?(path.to_s)
    rescue StandardError
      nil
    end

    def text_attachment?(attachment, extension)
      TEXT_EXTENSIONS.include?(extension) || attachment.content_type.to_s.start_with?("text/") || attachment.content_type == "application/json"
    end

    def text_body(attachment)
      path = file_path(attachment)
      return unless path

      data = File.binread(path, MAX_BYTES + 1)
      truncated = data.bytesize > MAX_BYTES
      text = data.byteslice(0, MAX_BYTES).dup.force_encoding(Encoding::UTF_8).scrub
      truncated ? "#{text}\n[已截断]" : text
    end

    def pdf_text(attachment)
      path = file_path(attachment)
      return unless path

      bytes = File.binread(path, MAX_BYTES)
      strings = bytes.to_s.scan(/\((?:\\\)|[^()])*\)/).filter_map do |literal|
        literal[1..-2].to_s.gsub(/\\n/, "\n").gsub(/\\[()]/, "").scrub.strip.presence
      end
      strings.join("\n").byteslice(0, MAX_BYTES).presence
    end

    def attachment_line(entry)
      line = "附件 #{entry[:name]} #{entry[:meta]}"
      line = "#{line}（#{entry[:note]}）" if entry[:note]
      line = "#{line}\n#{entry[:body]}" if entry[:body].present?
      line
    end
  end
end
