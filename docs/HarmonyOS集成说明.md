# HarmonyOS 系统能力接入

ItemTrace 的编译、目标和最低运行版本均为 HarmonyOS API 26。应用内业务继续使用原有物品、批次、借还服务；系统入口负责解析参数、查询数据或打开待确认表单。

## 已实现的功能与入口

| 功能 | 应用入口 | 实现位置 |
| --- | --- | --- |
| 小艺查询与记录 | 我的 → 系统能力与隐私 | QueryItemsIntent、ManageItemIntent、ViewItemIntent |
| 系统功能搜索与物品实体查询 | 系统搜索；用户可关闭物品查询和位置展示 | FunctionIntentExecutor、ItemIntentEntity、insight_intent.json |
| 包装文字识别 | 新建/编辑物品的照片区域；补入批次 | RecognitionPanel、TextRecognitionAdapter、CaptureDraftService |
| 照片外观搜索 | 查找 → 同时按照片外观查找 | PhotoSearchService |
| 临期、借出待还、快速记录卡片 | 桌面添加服务卡片 | FormSnapshotProvider、forms/pages、form_config.json |
| 收纳二维码和 NFC | 我的 → 收纳位置二维码与 NFC 标签；位置管理 → 标签 | LocationLabelService、NfcLabelAdapter、LocationLabelPage |
| 接收照片/文字分享 | 系统分享面板 → ItemTrace | EntryAbility.handleExternalWant、ShareService |
| 分享物品、借出清单、位置清单 | 对应页面的分享入口 | SharePreviewPage、ShareService |
| 备份和恢复进度实况窗 | 我的 → 系统能力与隐私 → 备份进度实况窗 | BackupProgressService、PortableBackupService |
| 通知直达和大屏布局 | 到期通知；宽屏设备 | ReminderAdapter、ExternalNavigation、Index、ItemListPage |

## 业务处理规则

- 小艺查询读取应用当前数据。小艺的新增、消耗、借出和归还操作打开待确认页面，不在后台直接修改库存。
- 多个同名物品、多个批次、多个借出记录需要用户选择。实际保存继续调用 ItemCreateService、BatchService 和 LendingService。
- API 26 的 ItemIntentEntity.onQueryEntity 每次查询数据库，修改、删除物品无需维护另一份系统库存。搜索中的位置展示受单独开关控制。
- OCR 结果只生成候选值。没有明确到期日期标签时，不把生产日期当成到期日期，也不凭模糊保质期自行推算。可打开原图放大核对，再填入表单。
- 图片检索只分析已保存的物品照片。更换和删除照片会同步维护检索数据，结果再与当前数据库核对。名称搜索在图片能力失败时仍可使用。
- NFC 和二维码存放随机标签标识。location_label 保存标签与 managed_location.id 的关系，因此位置改名不影响标签。解除关联后，原标签无法继续打开位置。
- 数据库从版本 12 升到 13，只新增标签表和索引。标签随便携备份一起保存，并在恢复事务中与位置一同恢复。没有标签字段的既有备份按零个标签处理，恢复前预览会显示标签数量。
- 分享前可以预览，并选择是否附带位置、备注、借用人或照片。
- 实况窗仅用于用户主动发起且耗时超过短暂等待的备份、恢复进度。创建失败不会中断文件操作。提交恢复事务后不再接受取消；此前取消会清理临时照片。
- 备份/恢复使用系统短时任务申请执行时间，实况窗本身不保证应用一直在后台运行。进程终止时实况窗由系统结束，数据库事务保持原子性。
- 到期通知跳转到相应物品详情。名称、位置、到期日、库存变化后重新核对提醒；已经到期的同一提醒不会因刷新反复发送。
- 桌面卡片数据改变后刷新，配置每日 00:01 更新；应用保持前台跨天时也重新计算。
- 宽屏保留同一 Navigation 和页面状态，根据宽度展示位置侧栏、物品列表和详情。Ctrl+F 打开查找栏目，Ctrl+N 打开记录菜单。

## 平台申请和真机条件

### 小艺与系统搜索

应用包已包含 JumpFunctionPage、ViewSearchPageLocal，以及 QueryStoredItems、RecordStoredItem、ViewStoredItem 自定义意图和可查询的 ItemIntentEntity。平台侧需要以 com.imotong.itemtrace 对应的实际应用身份申请/配置接入，完成调试账号、意图注册和审核。

功能搜索声明中的页面标识为 add、scan、camera、search、expiry、loans。物品实体查询支持 entityId、name；是否在目标系统入口直接展示内容，必须以平台开通和端到端调试结果确认。编译通过、元数据存在、在应用内开关开启均不能代替平台审核通过。

- [意图接入流程](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/intents-access-flow)
- [API 26 可查询意图实体](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/insight-intent-decorator-development)
- [功能搜索接入](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/intents-skill-all-rec-function-search)

### 实况窗

在 AppGallery Connect 为实际应用申请推送及实况窗权益，并确认 PROGRESS 场景获准。代码通过本地 Live View Kit 创建、更新和结束实况窗，不依赖自建推送服务器。默认关闭，用户可在系统能力设置中开启。需要在已开通的签名包上验证通知中心、胶囊、锁屏和返回备份页。

- [实况窗场景与限制](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/liveview-introduction)

### 视觉和 NFC

Core Vision Kit 的 OCR、文本搜图要使用支持相应能力的真机。NFC 完整验收需要可读写的 NDEF 标签，读写时设备应亮屏、解锁并开启 NFC。写入会替换标签内容；应使用专门准备的测试标签。

- [Core Vision Kit 支持范围](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/core-vision-introduction)
- [NFC 标签读写](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/nfc-tag-access-guide)
- [系统分享接收](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/share-interface-description)

## 本地验证命令

使用 DevEco Studio 自带的 Node、JBR 和 SDK：

```sh
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$JAVA_HOME/bin:$PATH
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry@default -p product=default test --no-daemon
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon
```

测试命令显示 BUILD SUCCESSFUL 不能单独代表测试全部通过，应检查 test_result.txt 中的 Failure、Error、Pass。

安装测试包后，用 aa test 的 class 参数选择 SystemCapabilitiesDevice。该组测试使用专用图片、临时文件和独立测试数据库，不清空用户的物品数据。NFC 测试只检查设备能力和 NDEF 编码，不能代替贴近实体标签读写。

## 本次验证记录（2026-10-06）

- 本地测试：133 项通过，Failure 0、Error 0。
- Mate 80（设备返回 API 26）实机测试：38 项通过，Failure 0、Error 0。包括 OCR 测试图片、照片建索引/检索/删除、NDEF 标签编码、标签改名与解除关联、数据库升级，以及含标签的备份恢复回归。
- 应用和测试 HAP 编译、打包、签名成功。检查了安装包内的自定义意图、可查询实体和三种卡片声明。
- 实机打开系统能力设置页成功。未保存的新建表单被外部入口覆盖后返回，输入仍保留；测试草稿已放弃，没有新增用户物品。
- 尚未完成：小艺/系统内容搜索在平台开通后的端到端调用、PROGRESS 实况窗权益验证、实体 NFC 标签贴近读写，以及平板/折叠屏设备上的布局检查。
