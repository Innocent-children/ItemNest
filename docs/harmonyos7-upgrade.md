# HarmonyOS 7 / API 26 升级记录

## 版本与配置

- 华为[应用升级适配指导](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)确认 HarmonyOS 7.0 对应 API `26.0.0`，并推荐配套开发套件 `26.0.0`。本机 DevEco Studio `26.0.0` 内置正式版 SDK `26.0.0.105`；此前工程目标为 `6.1.1(24)`。
- 根 `build-profile.json5` 现在显式设置 `compileSdkVersion`、`targetSdkVersion` 为 `26.0.0`；`compatibleSdkVersion` 保留 `6.1.1(24)`。华为官方《应用升级targetSDKVersion兼容低版本指导》确认 `26.0.0 > 6.1.1(24)`，支持目标升级而最低兼容版本不变。
- 产物 `build/outputs/default/pack.info` 记录 `apiVersion.target=26`、`compatible=24`、`releaseType=Release`，构建生成的模块配置记录编译 SDK 为 `26.0.0.105`。
- `modelVersion` 保留原工程的 `6.1.1`。它是工程模型版本，不是目标 API；当前配置已通过新版 Hvigor 构建，不需臆测新模型版本。API 升级提交本身未改业务代码、数据格式、权限或依赖；下述独立功能分支另有业务改动。

## 验证

在独立分支 `codex/harmonyos7-api26`、DevEco Studio `26.0.0` / SDK `26.0.0.105` 下执行：

| 检查 | 结果 |
| --- | --- |
| `hvigorw test --mode module -p module=entry@default -p product=default -p buildMode=test --no-daemon` | 成功；`test_result.txt` 为 60 通过、0 失败、0 错误。 |
| `hvigorw assembleApp --no-daemon` | 成功；生成未签名 `.app` 和 HAP，ArkTS 编译通过。 |
| `hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=default -p buildMode=test --no-daemon` | 成功；测试 HAP 只完成编译打包，未在设备执行。 |
| DevEco CLI `check lint entry/src/main/ets` | 0 错误、5 警告；均在未改动的源文件，涉及小组件及循环内 `Date` 创建。 |
| DevEco CLI `check compat`：`HarmonyOS_6.1.1(24)_Release` → `HarmonyOS_26.0.0_Release` | CLI `1.3.0-stable` 将该顺序错误判定为目标版本不高于源版本，未产生扫描报告；官方兼容性文档明确版本顺序相反。 |

Hvigor 仅提示缺少签名、混淆配置建议，以及测试包资源同名颜色警告。当前 HDC 无可用连接（`Connect server failed`），仓库也无调试签名；因此没有真机或模拟器运行结论。DevEco Code Linter 报告位于临时目录，不属于仓库交付物。首次测试尝试曾因沙箱无法写入 Hvigor 默认用户缓存而失败；获得正式授权后以上验证成功。

## API 26 行为变化核对

DevEco CLI 内置官方《26.0.0 OS平台行为变更说明·总览》列出按 `targetSdkVersion` 生效的公共事件、ArkUI、文件访问、权限等变化。源码中未使用清单涉及的 `NodeAdapter`、`LayoutPolicy.matchParent`、`queryNavDestinationInfo`、`onScrollVisibleContentChange`、`fileIo.stat/access` 或 `READ_IMAGEVIDEO` 权限；文件存储使用应用私有目录及 `copyFile`，导航使用 `NavPathStack`。所以当前没有已证实需要改写的 Kit 调用。

目标 API 26 还可能改变 Dialog/Toast 默认视觉和部分表单控件触摸区域。应在有签名的 API 24 与 API 26 手机/平板上分别验证：新增/编辑/删除与 RDB v10 迁移、系统提醒授权/取消、Photo Picker 与图片复制、卡片刷新、返回导航、弹窗、深浅主题和安全区。官方[升级指南](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)也要求新老设备兼容性测试；编译通过不能代替运行验证。

## 应用功能地图

ItemTrace 是本地优先的个人物品管理应用。首页展示最近添加、临期和数量为零的待补货物品；用户可按名称搜索，并以位置、分类精确筛选，进入详情新增、编辑、确认删除。批次管理汇总父物品数量与最早到期日；借出、归还作为事件记录，不自动扣库存。树形位置、分类、主题、首页分区、排序和提醒偏好可管理；详情可设置低库存阈值，但没有独立系统低库存提醒。

业务数据存于 `itemtrace.db`，偏好存于 Preferences；照片从 Photo Picker 复制到应用私有目录。单一 `entry` 模块支持手机和平板，唯一声明的运行权限是 `PUBLISH_AGENT_REMINDER`，无网络权限。桌面卡片只展示计数。以下功能分支把 Schema 升至 v11，并补齐原先不可达的扫码与文件备份恢复。

## 独立功能分支（`codex/itemtrace-native-completion`）

- 使用系统 Scan Kit 扫描条码或二维码，也允许手工输入；结果单独保存在 `item.barcode`，名称搜索同时匹配条码。v10→v11 迁移添加可空列和索引，旧物品保留。
- 设置页可通过系统文档选择器导出、预览和恢复单文件 JSON 备份。备份包含物品、批次、位置、分类、借还记录、低库存阈值及私有照片字节；不包含偏好或系统提醒 ID，也不包含私有照片路径。文件上限 32 MB、单张照片 5 MB、照片总量 20 MB；导入检查数量、类型、引用、批次汇总和位置循环。确认恢复前先在应用私有目录保留安全备份，数据库替换在一个事务中执行；用户可导出最近一次安全备份。系统提醒在事务外取消和重建，失败会给出提示。
- 首页增加低库存阈值提示；“待补货”仍只表示数量为 0。借还页明确说明借还事件不扣减库存。详情页显示真实的默认提醒天数，卡片在首次加载期间显示“—”而非误报 0。
- 启动时清理未被当前物品引用的私有照片；首页卡片与低库存提示、物品卡片、表单分区展开、恢复预览加入短时位移/淡入过渡，原有按钮反馈保留。`Navigation` 沿用系统页面转场；系统“减少动画”开启时关闭路由动画并跳过自定义动效。首页、物品表单、详情和设置页限制平板最大内容宽度，移除关键文字截断。

此分支本地 Hypium 结果为 **70 通过、0 失败、0 错误**，覆盖条码校验、扫码成功/取消/故障降级、备份结构与关联、照片格式与大小上限。`assembleApp` 与 `ohosTest` HAP 编译成功，`git diff --check` 通过。API 26 手机模拟器上运行的 `ohosTest` 为 **25 通过、0 失败**，包含隔离数据库的 v10→v11 迁移、恢复中途失败回滚和系统 Base64 照片字节往返。DevEco Code Linter 报告 0 错误、2 条原有性能警告。隔离内存 SQLite 对 v11 条码列与批次汇总做了烟雾检查。

API 26 手机模拟器上还检查了空库备份导出、文档选择、恢复预览与确认、安全备份导出、Photo Picker 打开与取消、深色模式、安全区及表单展开。此前模拟器协议曾阻止首次启动；用户自行处理协议后才完成上述测试。真机直接安装未签名 HAP 返回 `9568320`（无签名文件），因此尚无真机运行结论。扫码相机、系统提醒授权、卡片刷新、减少动画及大字/平板布局尚需进一步设备核验。功能分支不包含真实用户数据或签名材料。

## 2026-10-05 原生动效改造

当前实现把底部导航放回原生 `Tabs`，通过 API 26 的 `barFloatingStyle` 和 `uiMaterial.ImmersiveMaterial` 提供悬浮材质。`Tabs` 的位置、重叠和高度直接在页面声明，材质修饰器仅配置视觉属性，避免返回或键盘变化后页签布局漂移。页签使用系统 Symbol，选中时播放一次弹跳。各业务页面由自己的 `NavDestination` 承载标题、返回和操作按钮；`PageHeader` 只绘制标题内容，背景和安全区交给原生导航与根页面处理。

`entry` 模块配置 `ohos.arkui.UIMaterial.state=enable`，统一启用系统菜单、弹窗和选择控件的材质与空间动效。半模态显式使用系统材质并移除遮挡材质的实色背景。API 26 调用先判断运行版本，再通过 `deviceInfo.apiAvailable('26.0.0')` 保护；最低兼容 API 24 保留。系统减少动画时关闭自定义转场、数字翻动、Symbol 动效以及材质交互形变和点光源。

- 物品缩略图通过 `ItemHeroMotion` 与 `Navigation.customNavContentTransition` 连续移动到详情，支持返回手势的进度、完成和取消。转场标识包含来源分区与物品标识；目标布局完成后开始动画，返回时重新测量来源位置。无法匹配来源或返回目标时使用系统导航。页面释放时清理动画回调和临时显示状态。
- 首页搜索入口与独立搜索页使用 `geometryTransition` 连续展开和收起，转场完成后聚焦输入。打开筛选前结束搜索编辑，关闭键盘；主栏目搜索使用独立组件标识。
- 列表、搜索和首页按物品标识复用卡片，更新、排序与筛选在显式动画中发布结果。缩略图由 `PhotoService.loadThumbnails` 读取，一次加载内合并相同资产的查询；搜索和刷新分别沿用各自的请求序列，在异步照片读取后再次确认请求有效。
- `InventoryMetrics` 和首页计数使用引用参数 Builder，确保数据更新能驱动文本。整数使用 `NumericTextTransition`，小数保留普通文本。消耗、借还操作继续使用实际返回的数量和原有库存规则。
- `localImageSource` 在界面层把磁盘路径转换为文件 URI；数据库和文件服务继续使用磁盘路径。列表、详情、转场和照片查看统一采用该转换，读取失败显示占位图。照片查看支持双指缩放、双击放大或恢复、拖动、关闭按钮和返回键，关闭按钮固定在图片上层。
- 新增入口使用系统操作菜单提供手动、扫码和拍照入口；扫码和拍照复用现有表单实现。位置页面支持子位置展开与收起。导航使用 `NavigationMode.Auto`，保留手机与大屏的原生导航布局。

最终使用 DevEco Studio 内置 Hvigor / Node.js / JBR 构建并签名，完成干净构建和本地 Hypium 回归：112 通过、0 失败、0 错误；`git diff --check` 通过。构建没有新增 API 兼容性警告，仍有原文件的异常处理提示。

API 26 实机 SGT-AL10 上已安装并检查首页与页签、排序菜单、搜索展开与返回、筛选半模态、手动录入和保存、详情共享元素转场、返回手势完成与取消、消耗后的数量及首页计数刷新、删除确认和列表刷新。临时物品从 2 消耗到 1、再到 0，详情、卡片和待补货计数一致；验证物品已删除，排序恢复到测试前的选项。照片查看用应用插画生成的临时本地文件验证了显示、双击放大、拖动和关闭；验证页面、自动入口和临时文件已移除，交付包使用正式页面源码重新构建并安装。

API 24、大屏分栏、系统减少动画开关以及双指触摸手势尚未在对应设备或设置下逐项验证；这些路径已实现，当前实机结论限定为上述实际检查项。
