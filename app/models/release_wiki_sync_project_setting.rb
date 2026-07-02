class ReleaseWikiSyncProjectSetting < ActiveRecord::Base
  MODES = %w[single_list multi_list].freeze

  belongs_to :project

  validates :project_id, presence: true, uniqueness: true
  validates :mode, presence: true, inclusion: { in: MODES }
  validate :config_json_must_be_valid_json

  before_validation :apply_defaults

  def self.for_project(project)
    find_or_initialize_by(project_id: project.id) do |setting|
      setting.mode = 'single_list'
      setting.enabled = false
      setting.main_page = 'Release_Notes'
      setting.config_json = JSON.pretty_generate({})
    end
  end

  def parsed_config
    raw = config_json.to_s.strip
    return {} if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end

  def list_configs
    lists = parsed_config['lists']
    return [] unless lists.is_a?(Array)

    lists.map do |item|
      next unless item.is_a?(Hash)

      page = item['page'].to_s.strip
      label = item['label'].to_s.strip
      next if page.blank?

      {
        page: page,
        label: label.presence || page
      }
    end.compact
  end

  def effective_release_page_prefix
    prefix = release_page_prefix.to_s.strip
    return prefix if prefix.present?

    parsed_config.dig('release_pages', 'prefix').to_s.strip
  end

  def begin_marker
    '<!-- RELEASE_SYNC_BEGIN -->'
  end

  def end_marker
    '<!-- RELEASE_SYNC_END -->'
  end

  private

  def apply_defaults
    self.enabled = false if enabled.nil?
    self.mode = 'single_list' if mode.blank?
    self.main_page = 'Release_Notes' if main_page.blank?
    self.config_json = JSON.pretty_generate({}) if config_json.blank?
  end

  def config_json_must_be_valid_json
    raw = config_json.to_s.strip
    return if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    errors.add(:config_json, "JSON 格式错误：#{e.message}")
  end
end
