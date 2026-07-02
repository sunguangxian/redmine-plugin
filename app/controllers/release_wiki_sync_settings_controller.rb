class ReleaseWikiSyncSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize
  before_action :find_setting

  def edit
  end

  def update
    attrs = setting_params
    attrs[:enabled] = attrs[:enabled] == '1'

    @setting.assign_attributes(attrs)

    if @setting.save
      flash[:notice] = 'Release Wiki 同步配置已保存。'
      redirect_to project_release_wiki_sync_settings_path(@project)
    else
      flash.now[:error] = 'Release Wiki 同步配置保存失败。'
      render :edit
    end
  end

  private

  def find_setting
    @setting = ReleaseWikiSyncProjectSetting.for_project(@project)
  end

  def setting_params
    params
      .fetch(:release_wiki_sync_project_setting, {})
      .permit(:enabled, :mode, :main_page, :release_page_prefix, :config_json)
  end
end
