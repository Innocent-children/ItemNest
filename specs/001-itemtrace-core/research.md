# Phase 0 研究：ItemTrace 本地物品追踪核心闭环

**日期**：2026-06-20  
**输入**：[功能规格](spec.md)、[实施计划](plan.md)、项目现有配置与宪章。

## 工程事实核验

- 根 `build-profile.json5` 声明 `targetSdkVersion` 与 `compatibleSdkVersion` 均为 `6.1.1(24)`，
  `runtimeOS` 为 HarmonyOS，模块清单只包含 `entry`。
- `entry/src/main/module.json5` 是 `entry` 类型 Stage 模块，主元素为 `EntryAbility`，已声明
  `phone` 和 `tablet`。当前另有备份 Extension，但没有提醒、表单或扫码 Extension 配置。
- 根 `oh-package.json5` 仅声明 Hypium 与 Hamock 开发依赖；`entry/oh-package.json5` 没有业务依赖。
  现有 ETS 仅有 `EntryAbility`、`EntryBackupAbility` 和示例 `pages/Index.ets`。
- 项目中未发现 RDB、Preferences、提醒/通知、相册/相机、Form Kit 或扫码能力的现有导入、
  权限声明和模块配置。因此这些能力不能被视为“已在本项目验证”。

## 决策记录

### 决策：保留单模块 Stage 架构

- **结论**：第一至三阶段均在 `entry` 内按 `common`、`model`、`data`、`service`、`pages`、
  `components` 和 `forms` 分层；不新增独立业务模块。
- **理由**：当前应用只有一个入口模块，功能规模仍以本地闭环为主。单模块降低路由、资源和依赖
  配置风险，目录分层已足够支持测试和后续迁移。
- **替代方案**：提前拆分 data/feature/Form 模块。因无复用或独立发布需求而拒绝。

### 决策：RDB Store 为第一阶段唯一业务数据源

- **结论**：物品使用 RDB Store 持久化；v1 只有 `item` 表。位置路径和分类在 v1 中保留为文本，
  到期状态实时计算。
- **理由**：满足本地可靠保存、条件查询、排序与后续迁移要求，同时不把 Batch、Location、
  Category 的独立关系提前带入 MVP。
- **替代方案**：用 Preferences 存储全部物品。因不适合结构化查询、索引和迁移而拒绝。

### 决策：Preferences 仅保存阶段二用户偏好

- **结论**：仅保存默认提醒天数、默认排序、首页分区可见性和主题偏好等轻量值。
- **理由**：这些值与具体物品无强关系；与 RDB 业务数据分离可避免错误覆盖和迁移复杂度。
- **替代方案**：将偏好混入 Item 表。因会污染领域数据、提高查询和迁移负担而拒绝。

### 决策：提醒采取“应用内状态优先、系统提醒可替换”

- **结论**：Phase 1 仅计算到期状态，默认提前 7 天；Phase 2 用 `ReminderAdapter` 隔离系统提醒/
  通知能力，保存提醒执行记录以支持取消、编辑后的重建和失败重试。
- **理由**：物品记录和临期可见性不能依赖权限或系统任务成功，且不得使用常驻后台任务。
- **替代方案**：Phase 1 直接调用系统提醒，或以后台循环轮询。前者缺少 SDK 核验，后者违反隐私和
  资源约束，均拒绝。

### 决策：图片采用应用管理的本地副本

- **结论**：Phase 1 只有字段和入口。Phase 2 的选择或拍摄成功后，将内容复制至应用管理的本地
  存储范围，RDB 仅保存本地图片标识和必要元数据；不上传、不共享、不依赖可失效的外部引用。
- **理由**：用户可控、删除清理明确，且图片选择/相机的取消或授权失败不会破坏 Item 记录。
- **替代方案**：只保存外部媒体引用或把图片编码进 RDB。前者生命周期不可控，后者会显著膨胀
  数据库，均拒绝。

### 决策：服务卡片默认最小化展示

- **结论**：Phase 2 卡片仅展示即将到期数量、今日提醒数量和快速新增入口；点击后进入应用，
  不展示物品名称、位置、备注或照片。
- **理由**：桌面环境可能被旁人看到，计数足以提供提醒价值并降低敏感信息暴露。
- **替代方案**：在卡片展示完整物品详情。因隐私风险高而拒绝。

### 决策：扫码使用可替换 Adapter

- **结论**：Phase 2 的 `ScanAdapter` 只定义“启动用户主动扫描、返回可选文本、可取消/失败”的
  领域契约。扫描文本仅预填备注或搜索条件，确认后才保存；第二阶段不新增物品编码字段。
- **理由**：当前工程未能从依赖或可见 SDK 环境确认具体扫码能力，接口隔离可避免未来替换影响。
- **替代方案**：在 Phase 1 绑定未验证的扫码 API。因会造成构建与权限风险而拒绝。

## 系统能力核验门禁

本次计划未编造任何未确认的 HarmonyOS API、包名、权限名或 `module.json5` 配置项。官方在线文档
检索在当前访问环境被 403 阻断，且项目没有已声明的系统能力依赖；Phase 0 已在本机工具链 SDK 中
确认下列声明文件存在。精确权限、调用语义和模块配置仍必须在对应实现前结合 SDK 声明、依赖解析
和最小构建验证确认：

| 能力 | 实现前必须确认 | 计划中的安全边界 |
|---|---|---|
| RDB Store | ArkTS 导入位置、数据库打开/升级/事务 API 与错误码 | `RdbDatabase`、`ItemDao`；若无法打开则不进入页面数据操作。 |
| Preferences | 偏好实例生命周期、键值限制与持久化时机 | `PreferenceRepository`，仅阶段二启用。 |
| 提醒/通知 | Kit、权限、创建/更新/取消语义、后台限制和通知渠道要求 | `ReminderAdapter`，失败后仅保留应用内临期状态。 |
| 相册/相机 | 系统选择器/相机入口、返回媒体访问方式、权限与复制策略 | `ImageSourceAdapter`，只在显式点击后请求。 |
| Form Kit | 表单 Extension 类型、配置、更新时机与启动主应用方式 | `FormSnapshotProvider`，快照只含计数。 |
| 扫码 | 当前 SDK 可用扫码能力、相机权限、结果格式与取消行为 | `ScanAdapter`，不可用时允许手工输入。 |

## Phase 0 退出条件

1. 在目标 DevEco Studio 环境打开工程并确认 `entry` 可同步、构建和运行。
2. 为每项阶段二系统能力记录：官方 SDK 证据、最小依赖、精确权限、模块配置、支持设备、
   取消/拒绝/失败行为与清理动作。
3. 任何未通过的核验都不得阻塞 Phase 1；必须保留 Adapter 接口和应用内降级，不得提前调用。
4. 将实际可用的构建、测试和设备运行命令补充到 [quickstart.md](quickstart.md)。

## Phase 0 执行记录（2026-06-20）

### T001、T002：工程与模块核验

- 根 `build-profile.json5` 已确认：目标和兼容 SDK 均为 `6.1.1(24)`，运行时为 HarmonyOS，
  模块清单仅有 `entry`。
- 根 `oh-package.json5` 的模型版本为 `6.1.1`，仅声明 `@ohos/hypium` 与 `@ohos/hamock`
  开发依赖；`entry/oh-package.json5` 没有业务依赖。
- `entry/build-profile.json5` 使用 `stageMode`，目标为 `default` 与 `ohosTest`；
  `entry/src/main/module.json5` 声明 `entry` Stage 模块、`EntryAbility`、`phone`、`tablet` 和
  现有备份 Extension。
- ETS 当前只有 `entryability/EntryAbility.ets`、`entrybackupability/EntryBackupAbility.ets` 与
  示例 `pages/Index.ets`；本地测试位于 `entry/src/test/`，设备测试位于 `entry/src/ohosTest/`。
- 项目是 Git 仓库，现有 `.gitignore` 已覆盖 `oh_modules/`、构建目录、`.hvigor/`、`.idea/` 与
  测试产物；未检测到 Docker、ESLint、Prettier、npm 发布、Terraform 或 Helm 配置，无需新增其他
  忽略文件。

### T003：HarmonyOS 系统能力核验

本机实际构建工具链 SDK 根目录为
`C:\Applications\Huawei\command-line-tools\sdk\default\openharmony`。下表的“已发现”仅表示
SDK 声明存在，不等同于已经配置权限或可以直接写入业务代码；精确调用、权限和 `module.json5`
配置仍须在对应 Phase 2 任务中按 SDK 声明复核。

| 能力 | 本机 SDK 声明证据 | Phase 0 结论 | 实施约束 |
|---|---|---|---|
| RDB Store | `ets/kits/@kit.ArkData.d.ts`、`ets/api/@ohos.data.relationalStore.d.ts` | 已发现 | Phase 1 可在实现前复核导入、打开、升级和事务语义后封装 `RdbDatabase`。 |
| Preferences | `ets/kits/@kit.ArkData.d.ts`、`ets/api/@ohos.data.preferences.d.ts` | 已发现 | 仅 Phase 2 使用；不得存放 Item 或图片业务数据。 |
| 提醒/通知 | `ets/kits/@kit.BackgroundTasksKit.d.ts`、`ets/kits/@kit.NotificationKit.d.ts`、提醒声明文件 | 已发现 | Phase 2 先确认权限、创建/更新/取消语义与后台限制，再实现 `ReminderAdapter`。 |
| 相册选择 | `ets/kits/@kit.MediaLibraryKit.d.ts`、文件选择/照片访问声明 | 已发现 | 仅在用户主动选择照片时接入；先确认授权与本地副本策略。 |
| 相机 | `ets/kits/@kit.CameraKit.d.ts`、相机选择声明 | 已发现 | 仅在用户主动拍摄时接入；先确认权限、返回结果与取消路径。 |
| Form Kit | `ets/kits/@kit.FormKit.d.ts`、`FormExtensionAbility`/Provider 声明 | 已发现 | Phase 2 先确认 Extension 配置和刷新生命周期；卡片只读汇总计数。 |
| 扫码 | 未找到可直接作为通用扫码能力的明确 SDK 声明 | 待后续能力核验 | 继续保留 `ScanAdapter` 和手工输入降级；不得写死 Scan Kit 依赖或权限。 |

### T004：构建与测试路径核验

- 已确认命令行工具：`hvigorw.bat` 和 `ohpm.bat` 位于本机 Huawei command-line tools。
- 已执行 `hvigorw.bat tasks`：成功列出 `entry` 与应用级任务，包含 `assembleApp`。
- 已执行 `hvigorw.bat assembleApp --no-daemon`：构建成功，耗时约 9 秒，生成 `entry/build/` 产物。
- 构建警告：当前 `build-profile.json5` 未配置签名，因此跳过 HAP/App 签名；这不阻塞本地编译，
  但在真机安装前必须由签名配置任务单独处理。另有现有混淆配置建议，不在本阶段修改。
- 当前 `hvigorw tasks` 未列出可直接调用的设备测试任务。Phase 1 开始后，本地测试以
  `entry/src/test/` 为目标；设备测试使用 DevEco Studio 选择 `ohosTest` 目标或在工具任务出现后
  补充已验证命令。

### T005、T006：治理核验与 Phase 1 准入结论

- 已读取 `AGENTS.md`、宪章、规格、计划、数据模型、契约、研究、验证指南和任务清单。所有文档
  一致要求 ArkTS、ArkUI、Stage Model、RDB Store、本地优先和最小权限。
- 未发现后端、账号、云同步、多人共享、广告、第三方统计或常驻后台任务要求；这些能力不得在
  后续任务中引入。
- **Phase 1 准入：通过。** 可开始 Item 模型、字段校验、RDB Schema/DAO/Repository 和页面路由。
  Phase 2 的提醒、图片、Form Kit 和扫码必须继续经过各自 API/权限核验；扫码保持可替换 Adapter。

## Phase 2 API 核验与实现记录（2026-06-20）

### Preferences（T051）

- 本机 `@ohos.data.preferences.d.ts` 和 `@kit.ArkData.d.ts` 确认：`preferences.getPreferences(context, name)`、
  `Preferences.getSync`、`put`、`flush` 均可用。Preferences 的值类型覆盖 number、string、boolean 等轻量值。
- 实现使用文件 `itemtrace_user_preferences`，只保存默认提醒天数、默认排序、首页分区、主题和提醒开关；
  不保存 Item、Asset、ReminderRecord 或外部 URI。
- 写入失败转换为 `PREFERENCE_WRITE`，读取失败转换为 `PREFERENCE_READ`；页面保留默认值和本地 Item 闭环。

### Reminder / Notification（T054）

- 本机 `@ohos.reminderAgentManager.d.ts` 与 `@kit.BackgroundTasksKit.d.ts` 确认：
  `publishReminder`、`cancelReminder`、`getAllValidReminders` 及 `ReminderRequestCalendar` 可用。
- `publishReminder` 的 SDK 声明要求 `ohos.permission.PUBLISH_AGENT_REMINDER`，因此该精确权限已写入
  `entry/src/main/module.json5`；没有引入常驻后台任务、网络或账号。
- 调度使用日历提醒，当地日期 09:00；保存/编辑先取消旧任务，再创建新任务；未开启提醒、无到期日、
  提醒时刻已过或物品已过期时只记录 `NOT_REQUIRED`。系统拒绝或创建失败写入 `FAILED` 并由详情页提供重试。
- 仍需在真机确认：权限是否弹窗、通知开关关闭时的实际错误码、提醒投递时刻与取消后的系统展示。

### 图片与相机入口（T060）

- 本机 `@ohos.file.photoAccessHelper.d.ts` 与 `@kit.MediaLibraryKit.d.ts` 确认：
  `PhotoViewPicker`、`PhotoSelectOptions`、`PhotoSelectResult.photoUris`、`isPhotoTakingSupported` 可用。
- 本机 `@kit.CoreFileKit.d.ts` 确认：`fileIo.mkdir`、`copyFile`、`unlink` 可用于应用私有目录；
  `Context.filesDir` 是应用文件目录。
- `@ohos.multimedia.cameraPicker` 的 `pick` 声明要求来自 UIExtensionAbility 的 Context，当前工程主流程是
  UIAbility 页面，不能把该 API 直接当作普通页面相机入口。当前“拍摄照片”使用系统 Photo Picker 的
  `isPhotoTakingSupported=true` 入口；如设备不提供拍摄入口，会返回表单并保留草稿。
- 选择器 URI 仅在用户保存时复制到 `filesDir/itemtrace-assets/`；RDB 仅保存 `item_asset` 元数据和
  `item.photo_local_id`，不保存二进制或外部 URI。真机必须验证系统 Photo Picker 的临时授权 URI 能否直接复制。

### 扫码（T066）

- 本机 `@ohos.scan.d.ets` 的 SystemCapability 为 `PrintFramework`，权限为 `ohos.permission.PRINT`，
  表示打印设备扫描，不是应用条码/二维码相机扫描能力。
- 结论：当前不接入该 API、不申请打印权限；`ScanAdapter` 明确返回不可用，表单仍支持手工输入扫描文本并在用户点击“添加到备注”后持久化为备注内容。
- 若后续获得可用 Scan Kit 或系统相机扫码 API，必须重新核验权限、取消语义、返回格式与隐私影响后替换 Adapter。

### Form Kit（T069）

- 本机 `@kit.FormKit.d.ts`、`FormExtensionAbility.d.ts`、`formBindingData.d.ts` 确认：
  `FormExtensionAbility`、`formBindingData.createFormBindingData`、`formProvider.updateForm` 可用。
- 已读取本机 DevEco 自动生成的 Form 模板，确认 `extensionAbilities.type = "form"`、metadata 名称
  `ohos.extension.form` 及 `form_config.json` 的 `forms`、`src`、`uiSyntax`、尺寸、刷新字段格式。
- 服务卡片仅绑定 `dueSoonCount` 与 `todayReminderCount`，并使用 FormLink 打开主应用；不输出 Item 名称、位置、备注或照片。
- 仍需在目标桌面确认：绑定计数的首帧/刷新显示、桌面添加流程、FormLink 是否可直接抵达新增表单，以及不同卡片尺寸的视觉效果。

## 2026-06-23 在线官方文档与本机复核

### 页面导航与刷新

- 华为官方文档 `页面路由(@ohos.router)(不推荐)`（2026-05-26）已将传统页面路由标为不推荐；ArkUI FAQ 建议
  `Navigation` / `NavPathStack` 使用 `pushPath` 的 `onPop` 回调和 `pop(result)` 接收返回结果。
  本轮已把页面整体迁移为 `Index.ets` 单入口 `Navigation(this.pathStack)` 宿主，所有业务页面改为
  `NavDestination` 内的 `@Component export struct`，`main_pages.json` 仅保留 `pages/Index`。
- `NavigationHelper` 已移除 `@ohos.router` 依赖，改为注册当前 `NavPathStack` 并通过
  `pushPathByName`、`clear`、`pop(result)` 和 `getParamByIndex` 封装应用内跳转。路由参数新增
  `NavigationRouteParams` 显式接口，避免 ArkTS 在 `Object` 参数下拒绝未声明 object literal。
- 本次修复不继续依赖旧 `router.back` 返回参数是否能被来源页稳定读取；保存成功后通过
  `AppEventBus.notifyDataChanged()` 增加全局数据修订号，首页、列表和详情在 `onPageShow` 与
  `@StorageLink` watch 中比较修订号后重新查询，覆盖隐藏页面错过事件或返回参数失效的情况。
- 服务卡片 `FormLink` 的快速新增不再由 `EntryAbility` 直接调用导航。Ability 只写入
  `itemtrace.quickAddRequest`，由 `Index` 在 `NavPathStack` 注册后消费并打开新增表单，避免冷启动时
  导航栈尚未就绪导致快速新增请求丢失。

### RDB Store 与提醒

- 华为官方 `通过关系型数据库实现数据持久化 (ArkTS)`（在线检索版本日期 2026-06-12）继续推荐 Stage 模型使用
  `@kit.ArkData` 的 `relationalStore.getRdbStore`、`createTransaction`、`execute`、`querySql`、
  `insert/update/delete/query`；文档强调数据库升级推荐使用事务保证原子性。
- 已将 `RdbDatabase` 的迁移流程和业务写事务从 `beginTransaction/commit/rollBack` 收敛为
  `createTransaction()` 事务对象，并将 schema SQL 从 `executeSql` 改为事务对象 `execute`。数据库版本更新
  改为在同一事务内执行 `PRAGMA user_version = ${DATABASE_VERSION}`，避免 schema 已提交但版本号未更新导致
  下一次启动重复迁移。构建通过；剩余 ArkTS warning 集中在 schema SQL、ResultSet getter、少量 Repository
  查询结果读取等“可能抛异常”调用，后续应补更细粒度异常转换与失败路径测试。
- 搜索页已纳入与首页/列表/详情一致的数据修订号刷新模型：从搜索页底部 `+` 新增物品返回后会按 revision
  刷新筛选选项和已搜索结果，同时避免 `onPageShow` 与 `@StorageLink` watcher 双重刷新。首页订阅的
  `AppEventBus` listener 已在 `aboutToDisappear` 释放，避免页面重建后重复监听。
- 数据层 ArkTS “Function may throw exceptions” warning 已收敛：新增 `ResultSetReader` 统一包装
  `ResultSet.goTo*`、`getColumnIndex`、`isColumnNull`、`getString/getDouble/getLong` 与 `close`，新增
  `SchemaExecutor` 统一包装 schema 迁移 SQL 的 `Transaction.execute`。库存阈值保存不再在写事务内重新
  打开 `RdbStore` 查询，改为使用同一个 `relationalStore.Transaction` 查询。迁移到 `Navigation` 后，
  当前 ArkTS 编译不再出现 router deprecated warning。
- 华为官方 `代理提醒(ArkTS)`（更新时间 2026-06-12）明确代理提醒存在管控、普通应用有效提醒数量上限、
  `ohos.permission.PUBLISH_AGENT_REMINDER` 权限、通知授权和 Notification Kit 关系；错误码文档
  （更新时间 2026-06-13）列出 `1700001` 通知未开启、`1700002` 数量超限等处理路径。当前提醒功能仍必须
  保持应用内临期列表降级，不得把系统提醒成功作为 Item 保存前置条件。

### macOS 构建复核

- 当前本机 DevEco SDK 根目录应设置为 `/Applications/DevEco-Studio.app/Contents/sdk`，而不是
  `.../sdk/default` 或 `.../sdk/default/openharmony`。使用后两者会触发 `SDK component missing`。
- 已执行：
  `env DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon assembleApp`
- 初次结果：`CompileArkTS`、`PackageHap` 均完成；最终失败在 `SignHap`，因为根 `build-profile.json5`
  的 `signingConfigs.default.material` 指向 Windows 路径
  `C:\Users\zero\.ohos\config\default_ItemTrace_...p12`。
- 已移除无效 Windows 签名材料与密码后重新执行同一命令，结果为 `BUILD SUCCESSFUL`。当前产物使用
  无签名本地构建路径；真机安装仍需在 DevEco Studio 中为当前机器重新生成调试签名材料。
- 完成 `Navigation` / `NavPathStack` 迁移后再次执行同一 `assembleApp` 命令，结果为
  `BUILD SUCCESSFUL`。构建剩余警告为混淆配置建议、DevEco 打包工具内部 `sun.misc.Unsafe` 终端弃用
  提示，以及无签名配置提示；没有 ArkTS 编译错误或 router deprecated warning。
- 华为单元测试 FAQ（更新时间 2026-06-03）说明 `@ohos/hypium` 1.0.25 及以上可用于当前测试场景；
  项目当前根 `oh-package.json5` 使用 `@ohos/hypium` 1.0.25。已新增 `AppEventBus` 本地单测并接入
  `entry/src/test/List.test.ets`，同时新增 `entry/src/ohosTest/ets/test/AppEventBusFlow.test.ets` 并接入
  `entry/src/ohosTest/ets/test/List.test.ets`，覆盖刷新链路共同依赖的数据修订号和监听释放机制。
- 本机 `hvigorw --no-daemon tasks` 未直接列出测试运行任务。已确认不能把 `ohosTest` 当作 product，
  也不能把 `ohosTest` 关联到 product；可用的测试包编译命令是
  `hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=default -p buildMode=test --no-daemon`。
  该命令已通过并执行 `OhosTestCompileArkTS`，但尚未在设备上运行测试用例；后续必须通过 DevEco Studio
  测试入口或确认的 `aa test`/Hypium 流程执行后才能把 T098/T100 标为完成。
