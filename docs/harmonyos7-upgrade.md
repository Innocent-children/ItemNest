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
