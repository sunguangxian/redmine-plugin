Rails.application.routes.draw do
  get 'projects/:project_id/release_wiki_sync_settings',
      to: 'release_wiki_sync_settings#edit',
      as: 'project_release_wiki_sync_settings'

  patch 'projects/:project_id/release_wiki_sync_settings',
        to: 'release_wiki_sync_settings#update'

  post 'projects/:project_id/release_wiki_sync_settings',
       to: 'release_wiki_sync_settings#update'
end
