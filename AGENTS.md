# AGENTS.md

本文件适用于整个 `ItemTrace` 仓库。默认使用中文沟通、说明和 UI 文案；ArkTS 标识符与文件名使用英文。

## 开始工作前

1. 非简单任务先读取根目录 `AGENT_MEMORY.md`；若不存在则按用户约定创建，并在每个计划步骤完成后更新。除非用户明确要求，不提交该文件。
2. 先运行 `git status --short --branch`。保留已有修改、删除和未跟踪文件，不恢复、不覆盖、不顺手清理用户改动。
3. 修改前阅读相关源码、配置和测试。复杂业务变更再阅读 `specs/001-itemtrace-core/` 下对应的规格、数据模型和契约。
4. 源码、`module.json5` 和 build profile 用于判断当前实现与 SDK 配置；当前用户请求定义本次目标，适用的 `spec.md` 和 contracts 是需求约束。三者冲突时先报告差异，不要静默用源码覆盖需求。早期 `plan.md`、`tasks.md`、`Architecture.md` 只作历史参考。
5. 未经用户要求，不创建分支、提交、推送、修改 Git 历史或恢复已删除的 `.agents/`、`.specify/`、`.codebase-memory/`。

## 项目定位

ItemTrace 是一个面向 HarmonyOS 手机和平板的本地优先个人物品管理应用，不是物流或快递追踪系统。它帮助用户回答：物品放在哪里、还有多少、何时到期、是否借出。

用户当前可达的主要能力：

- 物品新增、查看、编辑、确认删除，记录名称、数量/单位、位置、分类、到期日、提醒天数、备注和本地照片，并在详情页设置低库存阈值。
- 首页展示最近添加、即将到期、数量为 0 的待补货物品，以及常用位置快捷入口。
- 按名称搜索，按位置和分类筛选；搜索页记录本地查询历史，物品详情会以去重方式记录最近查看。
- 管理物品批次；批次数量总和与最早到期日回写到父物品。
- 记录借出/归还事件；借还记录不会自动扣减主物品库存。
- 管理树形位置、预置/自定义分类、主题、首页分区、排序和提醒偏好。
- 使用系统提醒、Photo Picker、应用私有图片存储，以及仅展示汇总计数的桌面服务卡片。

本项目默认无账号、无后端、无云同步、无广告和第三方统计，也没有网络权限。物品、家庭位置、到期信息、备注和照片都按敏感本地数据处理。

## 当前明确边界

- 扫码尚不可用：`UnavailableScanAdapter` 只返回降级提示，表单支持手工输入文本并追加到备注。不要把扫码描述成已实现能力。
- 首页“待补货”只表示 `quantity === 0`。物品详情页可设置低库存阈值并显示应用内状态，但目前不会发布独立系统低库存提醒。
- 导出/备份服务可以生成 JSON 字符串，但没有可达 UI，也不会自行写入本地文件。
- 导入/恢复目前只做格式校验、预览和用户确认，不会把数据写入 RDB。
- `EntryBackupAbility.ets` 是占位实现，未在模块清单注册，且 `backup_config.json` 明确关闭系统备份恢复。
- 根构建配置没有签名。无签名可完成本地编译，但真机安装和设备测试前必须配置本机调试签名；不得提交证书、密码或本机签名路径。

## 技术事实

- 目标 HarmonyOS `7.0` / API `26.0.0`，最低兼容 `6.1.1(24)`；使用 ArkTS、ArkUI 声明式 UI、Stage Model、`UIAbility`。
- 单一业务模块 `entry`，Bundle 为 `com.imotong.itemtrace`，支持 `phone`、`tablet`。
- 根/模块构建由 Hvigor 管理；项目模型版本 `6.1.1`。仓库不包含 `hvigorw` wrapper。
- 业务数据使用 ArkData RDB：`itemtrace.db`，当前 `DATABASE_VERSION = 10`。
- 轻量设置使用 Preferences；用户图片复制到 `context.filesDir/itemtrace-assets/`，RDB 只存元数据和本地 Asset ID。
- 原生能力来自 HarmonyOS SDK：AbilityKit、ArkData、ArkUI、BackgroundTasksKit、CoreFileKit、FormKit、MediaLibraryKit 等。
- 唯一声明的运行权限是 `ohos.permission.PUBLISH_AGENT_REMINDER`。
- 测试依赖为 `@ohos/hypium` `1.0.25` 和 `@ohos/hamock` `1.0.0`；没有第三方业务运行依赖。

## 目录地图

- `AppScope/`：应用级 Bundle、名称和图标资源。
- `entry/src/main/ets/entryability/EntryAbility.ets`：Ability 生命周期、`AppServices` 初始化、主题、安全区和卡片快速新增入口。
- `entry/src/main/ets/pages/Index.ets`：唯一注册到 `main_pages.json` 的根页面、全局 `NavPathStack` 和首页。
- `entry/src/main/ets/pages/`：ArkUI 页面；负责页面状态和调用应用服务，不直接访问 RDB。
- `entry/src/main/ets/components/`：无数据库访问的可复用组件。
- `entry/src/main/ets/model/`：领域模型和派生状态。
- `entry/src/main/ets/common/`：`Result<T>`、`AppError`、校验、事件总线和导入校验。
- `entry/src/main/ets/service/`：应用用例；`AppServices.ets` 是依赖装配入口。
- `entry/src/main/ets/service/adapter/`：提醒、选图、扫码等系统能力边界。
- `entry/src/main/ets/data/rdb/`：数据库打开、事务、版本迁移和表结构。
- `entry/src/main/ets/data/dao/`：需要独立 DAO 的参数化持久化和行映射。
- `entry/src/main/ets/data/repository/`：领域数据访问边界；部分简单实体直接在 Repository 内封装 RDB，因此不要强制所有实体新增 DAO。
- `entry/src/main/ets/navigation/`：路由名、参数、返回结果和刷新契约。
- `entry/src/main/ets/forms/`：桌面服务卡片 Ability 和卡片 UI。
- `entry/src/main/resources/`：模块字符串、亮/暗主题颜色、尺寸、媒体和 profile。
- `entry/src/test/`：本地 Hypium 测试；总入口为 `entry/src/test/List.test.ets`。
- `entry/src/ohosTest/`：设备测试；总入口为 `entry/src/ohosTest/ets/test/List.test.ets`，测试模块名为 `entry_test`。
- `specs/001-itemtrace-core/`：需求、计划、数据模型、系统边界、导航和导入导出契约。
- `.hvigor/`、`.idea/`、`oh_modules/`、`build/`、`entry/build/`、`.test/`：本地生成内容，不手工编辑或提交。
- `error/`：历史崩溃诊断文件；不要在回复、日志或提交中泄露其中可能包含的本机信息。

## 架构与依赖方向

主链路保持：

`ArkUI Page -> AppServices -> Use-case Service -> Repository -> DAO/RDB`

系统能力链路保持：

`Page -> AppServices -> Service/Adapter -> HarmonyOS Kit`

执行规则：

- 页面不得导入 `data/dao`、`data/rdb`，不得直接实例化 Repository，也不得绕过 Service/Adapter 实现领域业务或持久化。Ability、Form 以及窗口/主题等 UI 胶水代码可在自身边界直接调用对应 Kit。
- 新用例放在 `service/`，依赖从构造器注入，并在 `AppServices` 集中装配。时间相关逻辑继续注入 `clock`，便于确定性测试。
- 可复用组件只依赖展示模型、回调和导航契约，不访问数据库。
- 持久化和系统失败跨层返回 `Result<T>`；页面必须先检查 `result.ok`。新增错误使用 `AppErrorCode` 和可操作的中文提示，不向 UI 泄露原始堆栈、SQL、私有路径或敏感字段。
- 新增/编辑主记录成功后，照片或提醒同步失败只提示用户，不回滚已经保存的主记录。当前删除流程必须先成功取消已知提醒，图片清理则是删除后的尽力操作；新增系统能力仍须覆盖取消、拒绝、不可用和失败降级。

## 导航、状态与 UI 约定

- `main_pages.json` 只保留 `pages/Index`；业务页由 `Navigation`/`NavPathStack` 承载。
- 新增页面时同步更新 `RouteName.ets`、`RouteContract.ets`、`Index.navDestinationBuilder` 和路由测试；使用 `NavigationHelper`，不要另建平行导航机制。
- 路由参数传稳定 ID、查询或显式结果，不传完整可变 `Item`。返回刷新使用 `refreshAt` 契约。
- 成功修改会影响其他页面列表、摘要或详情的共享业务数据后，调用 `AppEventBus.notifyDataChanged()`；偏好变更调用 `notifyPreferencesChanged()`。订阅必须在页面退出时释放。
- 页面沿用 loading/error/empty/content 状态，并在异步加载中防止旧请求覆盖新状态。
- 到期状态必须有文字，不只依赖颜色；位置路径的展示优先级高于分类；删除必须明确确认。
- 颜色新增或改名时同步维护 `resources/base/element/color.json` 与 `resources/dark/element/color.json`；尺寸优先复用 `float.json`。保持沉浸式安全区、手机和平板可读性。
- 当前用户文案主要为中文内联，不要声称已经完成国际化。

## 数据与领域约定

- `Item` 名称去除首尾空白后为 1–80 字符；数量为非负、最多两位小数，默认 `1`；单位默认“个”；提醒天数为 0–365；备注最多 500 字符。
- 到期日使用本地 `YYYY-MM-DD`。`ExpiryStatus` 和 `StockStatus` 是运行时派生值，不写入数据库。
- 名称搜索是部分匹配；位置和分类是精确筛选；组合条件取交集。
- 批次变更后必须保持父 `Item` 的数量汇总和最早到期日一致；已有批次的物品应在批次管理中修改数量、单位和到期日，并始终保留至少一个批次。借出/归还是追加式 `TraceEvent`，不要静默改变其现有库存语义。
- 照片选择 URI 只能是临时输入；保存时复制到应用私有目录，不能长期持久化外部 URI，也不能进入导出 JSON。
- 桌面卡片只展示临期/今日提醒计数，不得暴露物品名称、位置、备注或照片。
- 当前多表关系不依赖数据库级外键；Schema v10 使用事务内触发器维护批次汇总并清理 Item 关联记录，系统提醒和图片文件等外部副作用仍由服务层处理顺序与失败恢复。
- 修改 Schema 时递增 `DATABASE_VERSION`，按版本追加向前迁移，在事务中执行并保留失败回滚；同步更新 `specs/001-itemtrace-core/data-model.md` 和相关迁移测试。查询得到的 ResultSet 必须在 `finally` 中关闭。
- 新增网络、云同步、账号、统计、后台常驻任务或权限属于产品级变更，先取得用户确认并补充隐私与拒绝降级设计。

## 编码与变更规则

- 遵循现有 ArkTS 风格：2 空格缩进、单引号、分号、显式类型、英文标识符；不要用伪代码或未核验 API 冒充实现。
- 权威输入校验由 Service 或其调用的 `common` 校验器承担；页面可以即时提示，但不能作为唯一校验。DAO/Repository 不显示 UI，页面不拼 SQL。
- 保持变更小而聚焦。新增依赖、修改锁文件、增加权限或改变公开数据格式前先征得用户同意。
- 新增模型、页面、权限、系统 Kit 或导入导出字段时，同步相应规格/契约、测试和降级说明。
- 不手工编辑 `oh-package-lock.json5`，不提交签名、`.env`、设备标识、数据库、用户图片或构建产物。

## 构建与验证

前置条件：安装支持 HarmonyOS `7.0` / API `26.0.0` 的 DevEco Studio，并将 `$devecoHome` 指向安装目录。不要把本机绝对路径写入仓库。

```powershell
$devecoHome = '<DevEco Studio 安装目录>'
$env:DEVECO_SDK_HOME = "$devecoHome\sdk"
$env:NODE_HOME = "$devecoHome\tools\node"
$hvigorw = "$devecoHome\tools\hvigor\bin\hvigorw.bat"

& $hvigorw tasks
& $hvigorw test --mode module `
  -p module=entry@default `
  -p product=default `
  -p buildMode=test `
  --no-daemon
& $hvigorw assembleApp --no-daemon
```

编译 `ohosTest` HAP：

```powershell
& $hvigorw assembleHap --mode module `
  -p module=entry@ohosTest `
  -p product=default `
  -p buildMode=test `
  --no-daemon
```

注意：本地 `test` 任务在测试断言失败时也可能返回退出码 0，必须同时检查控制台中的 `ERROR:`、case 汇总和 `entry/.test/` 报告。测试 HAP 编译成功不等于 `ohosTest` 已在设备执行；设备测试仍需要调试签名和已连接的 phone/tablet。

测试规则：

- 先运行最窄的相关测试，再构建 `assembleApp`；涉及 RDB、Ability、Form、权限或设备行为时补充/执行 `ohosTest` 和手工设备验证。
- 新增本地测试文件后，必须在 `entry/src/test/List.test.ets` 中 import 并调用其默认 suite；设备测试同理更新 `entry/src/ohosTest/ets/test/List.test.ets`。
- 本地测试优先覆盖验证、Service、派生状态、迁移和路由契约；系统授权、RDB 真机行为、卡片和关键布局放入 `ohosTest`。
- `code-linter.json5` 只覆盖生产 `.ets`，测试与 mock 被忽略。使用 DevEco Studio Code Linter；仓库目前没有已核验的独立 lint/formatter CLI。
- 最终至少运行 `git diff --check`，并复核本次涉及文件的 scoped diff、未跟踪内容以及必要时的 staged diff；不要为了查看差异擅自 stage 文件。无法运行的命令要报告原因，不能把“能编译”写成“功能已在设备验证”。

## 完成标准

- 行为、数据迁移、路由、权限和降级路径与当前架构一致。
- 相关测试已注册并尽可能执行；构建、lint、设备测试的执行状态区分清楚。
- Diff 不包含无关修改、生成文件、秘密、本机配置或用户原有改动。
- `AGENT_MEMORY.md` 在非简单任务结束前已更新，但除非用户明确要求不纳入提交。
