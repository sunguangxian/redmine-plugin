# Redmine Release Wiki Sync

Redmine 插件：根据每个项目自己的 Wiki 发布记录结构，自动同步 Release 列表或主 Wiki 汇总页。

## 功能

- 每个项目单独配置，不在代码里写死项目名。
- 支持两种同步模式：
  - `single_list`：版本详情页变化后，自动重建一个 Release 列表页。
  - `multi_list`：多个 Release 列表页变化后，自动重建一个主汇总页。
- 只更新 `<!-- RELEASE_SYNC_BEGIN -->` 和 `<!-- RELEASE_SYNC_END -->` 之间的内容，避免覆盖手工维护的说明文字。
- 保存 Wiki 后自动触发同步，避免手动更新多个 Wiki 页面。
- 使用线程级递归保护，避免插件保存主页面时再次触发同步死循环。

## 安装

把插件放到 Redmine 的 `plugins` 目录：

```bash
cd /path/to/redmine/plugins
git clone https://github.com/sunguangxian/redmine-plugin.git redmine_release_wiki_sync
```

执行数据库迁移：

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

重启 Redmine。

## 权限配置

进入：

```text
管理 -> 角色和权限
```

给需要配置插件的角色勾选：

```text
Release Wiki Sync -> 管理 Release Wiki 同步配置
```

项目菜单会出现：

```text
Release同步
```

## 页面同步区域

插件只会修改下面两个标记之间的内容：

```text
<!-- RELEASE_SYNC_BEGIN -->
这里由插件自动生成
<!-- RELEASE_SYNC_END -->
```

建议把这两个标记放到 Release 列表或主汇总页面中需要自动生成的位置。

## 模式一：single_list

适合 TP35 这种结构：

```text
Release_Notes
├── Release_TP35_FW_V1_00_00_0030_20260320
├── Release_TP35_FW_V1_0_0_29
└── Release_TP35_FW_V5_3_7_14
```

配置示例：

```json
{
  "release_pages": {
    "prefix": "Release_TP35_FW_"
  }
}
```

也可以直接在页面表单里填写：

```text
主页面：Release_Notes
版本详情页前缀：Release_TP35_FW_
```

当新建或更新 `Release_TP35_FW_` 开头的 Wiki 页面后，插件会自动重建 `Release_Notes` 里的版本列表。

版本详情页建议写成：

```text
h1. V1.00.00.0030_20260320

发布日期：2026-04-13

h2. 修改内容

* 修复接收到 call alert 之后，发起呼叫在呼叫建立前走信道鉴权问题
```

生成结果示例：

```text
* [[Release_TP35_FW_V1_00_00_0030_20260320|V1.00.00.0030_20260320 (2026-04-13)]] - 修复接收到 call alert 之后，发起呼叫在呼叫建立前走信道鉴权问题
```

## 模式二：multi_list

适合 DP5X 这种结构：

```text
Changelog_for_5X
├── Release_Notes_Regular
├── Release_Notes_Trunking
├── Release_Notes_Record
└── Release_Notes_NP500
```

配置示例：

```json
{
  "lists": [
    { "page": "Release_Notes_Regular", "label": "常规版本 (5X)" },
    { "page": "Release_Notes_Trunking", "label": "Trunking 集群" },
    { "page": "Release_Notes_Record", "label": "Record 录音" },
    { "page": "Release_Notes_NP500", "label": "NP500" }
  ]
}
```

当上面任意一个列表页被编辑保存后，插件会自动更新主页面 `Changelog_for_5X` 的汇总区域，生成产品线索引、数量统计和 `{{include(...)}}`。

## 推荐的主页面写法

```text
h1. Release Notes

固件 bin 存放在项目文件，Wiki 仅记录变更。

{{toc}}

<!-- RELEASE_SYNC_BEGIN -->
这里由插件自动生成
<!-- RELEASE_SYNC_END -->
```

## 注意事项

- 插件不会上传 bin 文件，固件文件仍建议放在 Redmine 项目文件里。
- 如果页面没有同步标记，插件会把同步区域追加到页面末尾。
- `single_list` 模式依赖版本详情页标题前缀，例如 `Release_TP35_FW_`。
- `multi_list` 模式依赖 JSON 配置里的 `lists`。
