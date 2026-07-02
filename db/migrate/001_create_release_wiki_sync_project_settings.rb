class CreateReleaseWikiSyncProjectSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :release_wiki_sync_project_settings do |t|
      t.integer :project_id, null: false
      t.boolean :enabled, null: false, default: false
      t.string :mode, null: false, default: 'single_list'
      t.string :main_page
      t.string :release_page_prefix
      t.text :config_json
      t.timestamps null: false
    end

    add_index :release_wiki_sync_project_settings,
              :project_id,
              unique: true,
              name: 'idx_release_wiki_sync_project_settings_project'
  end
end
