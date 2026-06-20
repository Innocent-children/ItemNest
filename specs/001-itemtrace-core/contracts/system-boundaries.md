# 数据与系统边界契约：ItemTrace 核心闭环

本契约定义业务层对数据和系统能力的最小依赖。HarmonyOS 6.1.1(24) 的实际 Kit、导入、权限名和
配置项已在 Phase 2 实现前以本机 SDK 声明核验；未核验的扫码能力仍不得被页面直接调用。

## ItemRepository 契约

| 操作 | 输入 | 成功结果 | 失败语义 |
|---|---|---|---|
| 创建物品 | 已校验的 Item 草稿 | 新建 `itemId` 与完整 Item | 校验失败、数据库未初始化或写入失败；不生成半成品记录。 |
| 获取详情 | `itemId` | 完整 Item 或不存在结果 | 读失败不得伪装为不存在。 |
| 更新物品 | `itemId` 与已校验草稿 | 更新后的完整 Item | 不存在、校验失败或写入失败；保留原数据。 |
| 删除物品 | 已确认的 `itemId` | 删除成功 | 不存在或删除失败；UI 不得提前移除卡片。 |
| 查询列表 | `ItemQuery` 与排序规则 | Item 摘要列表 | 查询失败；返回可重试错误。 |
| 首页摘要 | 当前本地日期 | 最近添加、临期、待补货三组摘要 | 读取失败；页面显示摘要错误状态。 |

## 系统 Adapter 契约

| Adapter | 业务输入 | 业务输出 | 失败/降级 |
|---|---|---|---|
| `ReminderAdapter` | 物品、计划时间 | HarmonyOS Reminder ID 或取消结果 | 使用 `reminderAgentManager`；创建失败写入 `FAILED`，保留应用内临期状态与重试。 |
| `ImageSourceAdapter` | 用户主动选择“相册”或“拍摄照片” | 临时系统 Photo Picker URI 或用户取消 | URI 仅在保存时复制到 `filesDir`；不持久化外部引用，复制失败保留旧图片与草稿。 |
| `LocalAssetStorage` | 临时 URI、Asset ID | 应用私有路径 | 使用 CoreFileKit 复制/清理；图片二进制不进入 RDB。 |
| `ScanAdapter` | 用户主动扫描请求 | 可选文本结果 | 当前为不可用 Adapter：本机 `@ohos.scan` 是打印设备扫描，不申请打印权限；表单继续允许手工输入。 |
| `FormSnapshotProvider` | 当前本地日期 | 临期总数、今日计划提醒总数 | Form 快照不返回物品名称、位置、备注、照片或全量 Item。 |
| `PreferenceRepository` | 默认提醒天数、排序、首页分区、主题、提醒开关 | 已持久化偏好 | 失败返回领域错误；页面使用内置默认值且不影响 Item 数据。 |

## 数据流与隐私边界

1. 页面只把用户输入交给 Service；Service 通过 Repository 访问 RDB；DAO 不向页面返回数据库行。
2. 图片、提醒、扫码和卡片不得上传物品、位置、注意事项或照片。服务卡片只读取汇总计数。
3. 系统 Adapter 返回的失败必须转换为可操作的领域状态，不能在 UI 中暴露未核验 API、权限名、
   文件路径或原始错误堆栈。
4. RDB 持久化边界包含 `ItemRepository`、`ReminderRepository` 和 `AssetRepository`；Preferences
   仅持久化非敏感界面/提醒偏好。系统 Adapter 不能直接访问 ArkUI 页面状态。
5. 卡片仅通过 Form Kit 接收计数绑定数据，并以 FormLink 打开主应用；卡片不可用或刷新失败不影响主应用。
