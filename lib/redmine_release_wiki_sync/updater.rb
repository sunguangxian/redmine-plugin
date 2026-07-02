module RedmineReleaseWikiSync
  class Updater
    def self.call(changed_content)
      return if Thread.current[:release_wiki_sync_running]

      changed_page = changed_content.page
      return unless changed_page&.wiki&.project

      project = changed_page.wiki.project
      setting = ReleaseWikiSyncProjectSetting.find_by(project_id: project.id)
      return unless setting&.enabled?

      Thread.current[:release_wiki_sync_running] = true

      case setting.mode
      when 'single_list'
        call_single_list(changed_page, setting, changed_content.author)
      when 'multi_list'
        call_multi_list(changed_page, setting, changed_content.author)
      end
    ensure
      Thread.current[:release_wiki_sync_running] = false
    end

    def self.call_single_list(changed_page, setting, author)
      prefix = setting.effective_release_page_prefix
      return if prefix.blank?
      return unless changed_page.title.start_with?(prefix)
      return if changed_page.title == setting.main_page

      sync_single_list(
        wiki: changed_page.wiki,
        setting: setting,
        author: author
      )
    end

    def self.call_multi_list(changed_page, setting, author)
      list_pages = setting.list_configs.map { |item| item[:page] }
      return if list_pages.blank?
      return unless list_pages.include?(changed_page.title)

      sync_multi_list(
        wiki: changed_page.wiki,
        setting: setting,
        author: author
      )
    end

    def self.sync_single_list(wiki:, setting:, author:)
      main_page = find_wiki_page(wiki, setting.main_page)
      return log_missing_page(setting.main_page) unless main_page&.content

      prefix = setting.effective_release_page_prefix
      release_pages = WikiPage
        .where(wiki_id: wiki.id)
        .where('title LIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
        .includes(:content)
        .to_a

      items = release_pages.map do |page|
        parse_release_page(page, prefix)
      end.compact

      items.sort_by! do |item|
        [item[:date] || Date.new(1900, 1, 1), item[:version].to_s]
      end
      items.reverse!

      new_block = items.map do |item|
        date_part = item[:date] ? " (#{item[:date].strftime('%Y-%m-%d')})" : ''
        summary_part = item[:summary].present? ? " - #{item[:summary]}" : ''
        "* [[#{item[:page]}|#{item[:version]}#{date_part}]]#{summary_part}"
      end.join("\n")

      update_auto_block(
        page: main_page,
        setting: setting,
        new_block: new_block,
        author: author,
        comments: 'Auto sync release list from release pages'
      )
    end

    def self.sync_multi_list(wiki:, setting:, author:)
      main_page = find_wiki_page(wiki, setting.main_page)
      return log_missing_page(setting.main_page) unless main_page&.content

      lists = setting.list_configs
      return if lists.blank?

      lines = []
      lines << 'h2. 产品线索引'
      lines << ''

      lists.each do |item|
        page = find_wiki_page(wiki, item[:page])
        count = count_release_items(page)
        lines << "* [[#{item[:page]}|#{item[:label]}]] (#{count})"
      end

      lines << ''

      lists.each do |item|
        lines << "h2. #{item[:label]}"
        lines << ''
        lines << "[[#{item[:page]}|独立页面]]"
        lines << ''
        lines << "{{include(#{item[:page]})}}"
        lines << ''
      end

      update_auto_block(
        page: main_page,
        setting: setting,
        new_block: lines.join("\n"),
        author: author,
        comments: 'Auto sync release summary from release list pages'
      )
    end

    def self.update_auto_block(page:, setting:, new_block:, author:, comments:)
      page.content.with_lock do
        old_text = page.content.text.to_s
        begin_marker = setting.begin_marker
        end_marker = setting.end_marker

        new_text = if old_text.include?(begin_marker) && old_text.include?(end_marker)
          old_text.sub(
            /#{Regexp.escape(begin_marker)}.*#{Regexp.escape(end_marker)}/m,
            "#{begin_marker}\n#{new_block}\n#{end_marker}"
          )
        else
          old_text.rstrip + "\n\n#{begin_marker}\n#{new_block}\n#{end_marker}\n"
        end

        return if old_text == new_text

        page.content.text = new_text
        page.content.author = author if author
        page.content.comments = comments
        page.content.save!
      end
    end

    def self.parse_release_page(page, prefix)
      return nil unless page&.content

      text = page.content.text.to_s
      version = extract_version(page.title, text, prefix)
      date = extract_date(page, text)
      summary = extract_summary(text)

      {
        page: page.title,
        version: version,
        date: date,
        summary: summary
      }
    end

    def self.extract_version(title, text, prefix)
      text.lines.each do |line|
        match = line.match(/^h1\.\s*(.+)$/)
        return match[1].strip if match
      end

      suffix = title.sub(/^#{Regexp.escape(prefix)}/, '')
      normalize_version_suffix(suffix)
    end

    def self.normalize_version_suffix(suffix)
      value = suffix.to_s.strip

      if value =~ /^V(\d+)_(\d+)_(\d+)_(\d+)_(\d{8})$/i
        return "V#{Regexp.last_match(1)}.#{Regexp.last_match(2)}.#{Regexp.last_match(3)}.#{Regexp.last_match(4)}_#{Regexp.last_match(5)}"
      end

      if value =~ /^V(\d+(?:_\d+)+)$/i
        return 'V' + Regexp.last_match(1).tr('_', '.')
      end

      value
    end

    def self.extract_date(page, text)
      text_date = text.match(/(\d{4}-\d{2}-\d{2})/)
      return parse_date(text_date[1]) if text_date

      title_date = page.title.match(/_(\d{8})$/)
      if title_date
        raw = title_date[1]
        return parse_date("#{raw[0, 4]}-#{raw[4, 2]}-#{raw[6, 2]}")
      end

      page.created_on&.to_date
    end

    def self.extract_summary(text)
      lines = text.lines.map(&:strip)

      line = lines.find do |item|
        next false unless item.start_with?('* ') || item.start_with?('- ')
        next false if item.include?('[[Release_')

        true
      end

      return '' unless line

      line.sub(/^[-*]\s*/, '').strip
    end

    def self.count_release_items(page)
      return 0 unless page&.content

      page.content.text.to_s.lines.count do |line|
        line.match?(/^\s*[*-]\s+\[\[Release_[^\]|]+/)
      end
    end

    def self.find_wiki_page(wiki, title)
      WikiPage.find_by(wiki_id: wiki.id, title: title)
    end

    def self.parse_date(value)
      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end

    def self.log_missing_page(title)
      Rails.logger.warn("[release_wiki_sync] wiki page not found: #{title}")
    end
  end
end
