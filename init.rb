require 'redmine'

require_dependency File.expand_path('app/models/release_wiki_sync_project_setting', __dir__)
require_dependency File.expand_path('lib/redmine_release_wiki_sync/wiki_content_patch', __dir__)
require_dependency File.expand_path('lib/redmine_release_wiki_sync/updater', __dir__)

Redmine::Plugin.register :redmine_release_wiki_sync do
  name 'Redmine Release Wiki Sync'
  author 'SGX'
  description 'Auto sync release wiki pages with per-project configuration'
  version '0.1.0'

  project_module :release_wiki_sync do
    permission :manage_release_wiki_sync,
               { release_wiki_sync_settings: [:edit, :update] },
               require: :member
  end

  menu :project_menu,
       :release_wiki_sync,
       { controller: 'release_wiki_sync_settings', action: 'edit' },
       caption: 'Release同步',
       after: :wiki,
       param: :project_id
end

Rails.configuration.to_prepare do
  unless WikiContent.ancestors.include?(RedmineReleaseWikiSync::WikiContentPatch)
    WikiContent.prepend RedmineReleaseWikiSync::WikiContentPatch
  end
end
