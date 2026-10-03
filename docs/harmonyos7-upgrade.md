# HarmonyOS 7 / API 26 升级记录

## 版本与配置

- 华为[应用升级适配指导](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)确认 HarmonyOS 7.0 对应 API `26.0.0`，并推荐配套开发套件 `26.0.0`。本机 DevEco Studio `26.0.0` 内置正式版 SDK `26.0.0.105`；此前工程目标为 `6.1.1(24)`。
- 根 `build-profile.json5` 现在显式设置 `compileSdkVersion`、`targetSdkVersion` 为 `26.0.0`；`compatibleSdkVersion` 保留 `6.1.1(24)`。华为官方《应用升级targetSDKVersion兼容低版本指导》确认 `26.0.0 > 6.1.1(24)`，支持目标升级而最低兼容版本不变。
- 产物 `build/outputs/default/pack.info` 记录 `apiVersion.target=26`、`compatible=24`、`releaseType=Release`，构建生成的模块配置记录编译 SDK 为 `26.0.0.105`。
- `modelVersion` 保留原工程的 `6.1.1`。它是工程模型版本，不是目标 API；当前配置已通过新版 Hvigor 构建，不需臆测新模型版本。未改业务代码、数据格式、权限或依赖。

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

业务数据存于 `itemtrace.db`（Schema v10），偏好存于 Preferences；照片从 Photo Picker 复制到应用私有目录。单一 `entry` 模块支持手机和平板，唯一声明的运行权限是 `PUBLISH_AGENT_REMINDER`，无网络权限。扫码只有手工输入降级；导出服务只生成 JSON、没有可达文件 UI；导入/恢复仅校验预览，不写入数据库；系统备份关闭。桌面卡片只展示计数。
