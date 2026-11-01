# HarmonyOS 7 能力与接入要求

版本：1.1 · 调研日期：2026-11-01。目标为 HarmonyOS 7.0 手机，当前连接设备系统 `7.0.0.111(SP12C00E111R3P3)`，API 26。本文的“已核实”指官方资料或环境事实；应用接入结果由 `13` 的真机记录确认。

## 1. 系统能力怎样帮助用户

系统能力围绕五个时刻使用：用户打开页面时感到熟悉，记下物品时少输入，查找时少绕路，日期临近时得到帮助，换手机时继续拥有自己的记录。实现以官方组件的行为和系统设置为基准，产品自定义部分见 `06`、`07`。

| 编号 | 用户收益与页面 | 官方能力 | 接入状态与完成依据 |
| --- | --- | --- | --- |
| H01 | 熟悉的页面层级、悬浮导航和面板；P01—P23 | ArkUI Navigation、NavDestination、UI Design Kit | 官方能力已核实；A14、A22 真机接入验收 |
| H02 | 光感、跟手和舒适的反馈；P01、P03、P05 | API 26 沉浸光感、系统转场和手势动效 | 适用容器已核实；A14 真机观察 |
| H03 | 拍一张或选几张就能记下；P03、P06、P09 | CameraPicker、PhotoViewPicker、Image Kit | Picker 权限模式已核实；A02、A03、A17 |
| H04 | 从包装、标签提取文字；P17 | Core Vision Kit 文字识别 | API 合约已核实；设备模型及耗时由 A06 确认 |
| H05 | 图片从其他应用进入记录；P16 | Share Kit、UIAbility 外部输入 | 官方收图路径已核实；A15、A20 |
| H06 | 桌面直接找东西或记一件；P18 | Form Kit、FormExtensionAbility | 卡片路由方式已核实；A11 |
| H07 | 日期按天汇总，在日历提醒；P12、P21 | Calendar Kit | 个人版系统提醒路径；A10、A17、A28 |
| H08 | 自己掌握备份和清单；P13 | 系统文件选择器、应用沙箱、关系型数据库 | 文件格式见 `10`；A12 |
| H09 | 系统备份与换机衔接；P13 | BackupExtensionAbility | 系统调度与扩展配置已核实；A21 |
| H10 | 大字、朗读、明暗与窗口适配；P15 | ArkUI 系统字体、无障碍、颜色及窗口环境 | 产品规则见 `06`；A22 |
| H11 | 应用退出后由系统提醒；P12、P20、P21 | Background Tasks Kit 代理提醒、Notification Kit | 临期场景与 API 26 上限已核实；个人账号权益待核验；A26、A27 |
| H12 | 扫码查同款；P22 | Scan Kit 默认扫码 | 默认界面权限与 API 26 能力查询已核实；A29、A30 |
| H13 | 少打字，说出名称、说明或搜索词；P23 | Core Speech Kit 离线语音识别 | 语种、地区、录音模式与接口已核实；设备模型待验证；A31 |
| H14 | 长按图标直接进入任务；P18 | 静态快捷方式、Ability Kit 路由 | 四项配置上限及入口参数已核实；A32 |

## 2. H01—H02：导航、材质与动效

采用 Stage 模型。一级页面保持三个目的地，记录动作独立呈现。导航容器采用 ArkUI Navigation、NavDestination，底部页签优先使用 UI Design Kit 的 HdsTabs；页面路由与业务状态分别管理，返回后保留当前搜索、筛选与滚动位置。

HdsTabs 的基础组件自 API 20 提供，悬浮样式自 API 23 提供。横向底部页签通过 `barPosition(BarPosition.End)`、`vertical(false)`、`barOverlap(true)` 和 `barFloatingStyle` 配置，滚动联动通过对应页面的 `bindScroller` 绑定。`systemMaterialEffect` 使用组件实际提供的材质能力。接入时按安装的 HarmonyOS 7 SDK 声明核对属性签名。[HdsTabs API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdstabs#barfloatingstyle)

API 26 的沉浸光感包含材质与空间动效。通用组件的该类效果适用于 Navigation/NavDestination 标题栏及横向底部 Tabs；对话框、菜单、半模态及相关系统控件按各自文档使用。产品把材质放在导航和操作层，正文卡片采用清晰的实色表面。材质级别随设备算力、系统效果设置和深浅色变化，可通过 `uiMaterial.getGlobalMaterialLevel` 获取全局等级。[沉浸光感概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-overview)

UI Design Kit 当前官方说明的服务区域为中国大陆，相关沉浸表现需要真机观察。实现通过能力检查选择 HDS 组件；设备环境适合基础组件时，使用 ArkUI Navigation、Tabs、原生半模态和同一套语义颜色，保持入口、层级和内容一致。[UI Design Kit 简介](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/ui-design-introduction)

页面进退、底部面板和系统返回手势优先交由原生容器完成。自定义保存回执、卡片变化和按下反馈使用 `07` 的令牌。动画完成与业务保存分开判断，保存结果决定成功回执。

## 3. H03：拍照与选图

拍照使用 `@kit.CameraKit` 的 `cameraPicker.pick`，媒体类型为照片，传入当前 UIAbility 上下文。为记录创建可写的沙箱文件 URI 后，作为 `PickerProfile.saveUri` 传入；系统返回成功结果后校验 `resultUri` 并读取图片。这样用户的物品照片直接进入当前记录的保存流程。[CameraPicker API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-camerapicker)

相册使用 `@kit.MediaLibraryKit` 的 `photoAccessHelper.PhotoViewPicker`；选择上限由当前记录剩余照片数决定。系统 Picker 基于用户的选择授予临时访问，按官方权限指南使用这一访问范围。返回后立即复制到当前草稿的沙箱目录，再进行方向校正、缩略图生成及有效图片校验。[权限申请说明](https://developer.huawei.com/consumer/cn/doc/doccenter-app-security/bpta-permission-application)

用户取消时回到原草稿；图片读取遇到问题时保留其他内容，当前缩略图显示重新选择入口。文字输入始终可以完成记录。图片处理规格与容量提示见 `09`。

## 4. H04：照片文字候选

使用 `@kit.CoreVisionKit` 的 `textRecognition`。调用顺序为 `init()` 获得就绪布尔值，准备满足接口要求的 `PixelMap`，调用 `recognizeText(visionInfo, config)`，读取返回的文本及块、行信息，在生命周期结束时调用 `release()`。图像格式按官方要求采用 RGBA_8888。文字识别接口基线早于目标 API 26，实际可用性结合 `SystemCapability`、初始化结果和设备模型判断。[文字识别 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/core-vision-text-recognition-api)

结果进入 P17 候选区，最多突出 3 个名称候选，其余原文可继续选择。用户选中的内容才进入字段；名称、备注和日期均按当前草稿修订号处理。识别进行中仍可编辑或保存，保存后到达的结果结束于原会话。预计等待超过 8 秒时显示“可以先保存照片，稍后再补充文字”，用户可继续等待或返回。

完整年月日且通过日历校验的文本可成为日期候选。诸如“保质期 12 个月”的文字保留为原文；用户在 P20 选择生产日期和期限后查看计算结果，确认后写入正式日期。

官方目标检测列举了风景、动物、植物、建筑、人脸、表格、文本、食物、车辆、文档、卡片等类别。产品的名称建议以文字识别和用户命名为基础，目标检测仅在官方支持的类别场景中评估其价值。[目标检测 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/core-vision-object-detection-api#process)

## 5. H05：接收系统分享

在模块的分享声明中配置 `ohos.want.action.sendData` 与图片 UTD，接收上限为 9。UIAbility 的 `onCreate` 与 `onNewWant` 汇入同一入口，使用 `systemShare.getSharedData(want)` 获取共享数据，再从记录集合读取图片。

收到图片后先建立独立导入会话，逐个校验并复制到沙箱，然后展示 P16。用户选择记录方式、名称和位置后统一保存；保存动作标识确保同一确认只形成一批记录。来源应用返回行为交给系统导航栈。官方建议在长期使用前将共享文件复制到应用沙箱。[分享接口说明](https://developer.huawei.com/consumer/cn/doc/harmonyOS-Guides/share-interface-description)、[分享文件访问说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/share-kit-faq-0001)

入口参数包含来源类型、会话标识及本次资源引用。文件名、MIME 和 URI 都经过类型与长度校验。有效资源数量与保存按钮上的数量一致。

## 6. H06：桌面卡片

配置 2×2、2×4 FormExtensionAbility 卡片。卡片路由携带动作 `search`、`capture` 或受控的物品标识；UIAbility 统一解析，冷启动和热启动读取当前正式数据。

卡片点击路由按卡片类型采用 `postCardAction` 或 `FormLink`。Form Kit 官方区分 router、message 与 call 等事件，本产品的用户操作以打开对应应用页面为主。[卡片事件说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-ui-widget-event-overview?docScope=all)

首次添加展示通用入口。用户开启摘要后展示所选的最多 3 条常用记录；每次正式保存、状态变化或隐私开关变化后更新卡片数据。记录进入归档或回收站时清理对应摘要；旧入口打开时展示最新状态。卡片刷新受系统调度影响，应用页面以本地正式数据为准。

2×4 卡片可选择日期摘要模式，展示最多 3 条待关注日期、更新时间与“查看日期”入口。摘要排序与 P12 一致，刷新发生在应用数据提交及系统允许的卡片更新时机；跨日打开应用后重新计算。系统定时通知由 H07、H11 承接，卡片负责看一眼和直达。

## 7. H07：日历提醒

用户在 P21 开启到期提醒且本机通过日历承接时，按需申请 `ohos.permission.READ_CALENDAR` 与 `ohos.permission.WRITE_CALENDAR`。使用 `@kit.CalendarKit` 的 `calendarManager.getCalendarManager(context)` 获取管理器，创建应用专用 LOCAL 日历，名称为“我的家当”，配置提醒开启。

每个汇总后的提醒日创建一条 NORMAL 日程，开始时间为当地 09:00，结束时间 09:05，`reminderTime` 为 `[0]`。日程记录系统返回的 ID，用于后续修改与清理。采用 `addEvent`、`updateEvent`、`deleteEvent` 维护本应用的日程。汇总内容、去重与时区规则见 `09`。[日历事件开发指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/calendarmanager-event-developer)

官方 FAQ 对一般提醒场景推荐使用 Calendar Kit；本产品将用户可查看、修改的系统日历作为个人版系统提醒路径，与 H11 共用日期汇总规则。[提醒能力 FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faq-calendar-3)

日历默认显示汇总数量与“打开我的家当查看日期”。用户开启外部提醒详情后，说明列出名称、日期类型及日期；用户可按名称回到应用搜索。日历内的服务直达依赖相应服务登记，当前闭环由系统日历与应用内 P12 日期列表衔接。

用户当前保留应用内关注时，P12 完整展示日期和处理操作；完成日历授权后安排未来提醒。权限发生变化时保留日期并显示系统安排状态，重新获得权限后按当前数据核对应用专属日程。

## 8. H08—H09：文件、备份和换机

正式数据、草稿、照片和设置保存在应用沙箱。关系型数据使用平台关系型存储；缩略图属于可重新生成的数据。完整备份与 CSV 通过系统文件选择器让用户指定保存位置；外部导入以文件选择器授予的 URI 为读取范围。

系统备份配置 `BackupExtensionAbility`，在 `extensionAbilities` 声明 backup 类型，并通过 `ohos.extension.backup` 元数据指定配置。配置中纳入正式数据、照片、草稿和用户设置；缩略图缓存按需重建。使用官方提供的 `onBackup`、`onRestore` 等生命周期处理一致性快照与恢复后的校验。[备份恢复扩展](https://developer.huawei.com/consumer/cn/doc/harmonyOS-guides/app-file-backup-extension)

系统备份与换机由系统调度，应用提供数据范围与恢复适配。P13 说明系统设置中的操作入口，手动完整备份提供即时导出路径。[备份恢复概述](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/app-file-backup-overview)

恢复后先校验本地数据和资源，再重建检索与缩略图。日历 ID、卡片实例 ID 和临时访问授权属于设备上下文，恢复后根据当前设备重新关联，用户日期与常用选择继续保留。

## 9. H10 与设备接入清单

颜色、字体大小、屏幕可用宽度与系统动态效果设置进入统一 UI 环境状态。图标按钮提供中文朗读名称，状态通过文字与图形共同表达；半模态关闭后恢复焦点。系统选择器、日期选择器和原生控件沿用系统可访问行为。

开发开始时核对 DevEco Studio 和 HarmonyOS 7 SDK 实际安装版本、API 26 编译声明、HDS 依赖可用性、签名和真机运行条件。每项检查记录实际结果；能力条件与目标设备一致后接入对应页面。研发阶段的验证以连接手机为主，验收步骤见 A02、A06、A10—A12、A14、A15、A17、A21、A22。

## 10. H11：系统调度与普通通知

接入前完成 `16` 的 Q05—Q07：个人账号入口核验、场景审批、能力开关和新 Profile。手机代理提醒为受控能力；审批和签名满足后声明 `ohos.permission.PUBLISH_AGENT_REMINDER`。用户开启到期提醒且代理能力就绪时使用 Notification Kit 查询通知授权，并在用户操作中调用 `notificationManager.requestEnableNotification(context)`；页面分别记录权益、授权及实际登记结果。[代理提醒指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/agent-powered-reminder)、[通知概述](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/notification-overview)

通过 `@kit.BackgroundTasksKit` 的 `reminderAgentManager` 调用 `getValidReminders` 核对有效任务，使用 `addNotificationSlot` 配置 `SlotType.CONTENT_INFORMATION`。每日汇总采用 `ReminderType.REMINDER_TYPE_CALENDAR`，dateTime 填入年月日及当地 09:00；`publishReminder` 成功后保存返回 ID。设置唯一 notificationId、标题、正文、关闭按钮；重复月份和日期集合按单次任务配置。使用 `cancelReminder` 清理本应用旧任务。具体类型、回调签名与字段以 API 26 SDK 声明核对。

提醒的 wantAgent 指向 `com.imotong.itemnest` 的专用提醒 UIAbility；该组件只承担打开 P12 的职责，冷暖入口进入同一路由。独立提醒入口避免只依赖 pkgName/abilityName 的参数形式时丢失目的地。普通即时通知使用 WantAgent 同样打开 P12。点击后从本地读取当前日期状态。

API 26 单应用有效提醒上限为 64，API 25 及以前为 30，已弹出且仍有效的任务占用名额。按 `09` 查询、汇总、登记、保存结果；页面对剩余待安排日提供日历。登记成功的任务由系统在应用后台或进程结束后调度，实际通知横幅、锁屏、声音和震动由系统通知设置决定。原生验收覆盖进程结束、重启、系统开关和真实计划时刻，分别记录结果。

通知发布只负责当前消息展示。未来日期使用代理提醒或日历安排；每个汇总日的承载方式和有效标识由 ReminderDay 维护。初次授权、日期修改、时区变化及重新进入前台均按 `09` 核对。

## 11. H12：默认扫码查同款

使用 `@kit.ScanKit` 的 `scanCore.isDefaultScanSupported` 检查 API 26 默认扫码能力，再由当前页面调用 `scanBarcode.startScanForResult(context, options)`。options 选择本产品处理的商品码类型并开放相册；多码模式由用户点选一个码后返回。默认扫码界面由系统预授权访问相机，页面沿用系统交互。[默认界面扫码](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/scan-scanbarcode)

取得结果后按 `09` 的类型与原始码值匹配本地物品，保留前导零。已有记录展示数量、日期和位置；首次码值进入新建草稿，用户继续填名称或选照片。本产品的数据来源是用户自己的记录。取消返回原任务，设备能力待就绪时提供手动条码输入与普通搜索。

## 12. H13：离线语音填写

使用 `@kit.CoreSpeechKit` 的 `speechRecognizer`，先检查 `SystemCapability.AI.SpeechRecognizer`。`createEngine` 参数为 `language: 'zh-CN'`、`online: 1`、区域 CN、short 模式；这里 online 的枚举值 1 表示离线。服务区域和语种按官方简介核对，初始化结果决定设备模型是否就绪。[能力简介](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/core-speech-introduction)、[语音识别 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/hms-ai-speechrecognizer)

用户开始语音时按需申请 MICROPHONE，复用同配置引擎，先 `setListener` 再 `startListening`。采用 `recognitionMode: 0` 让系统执行实时录音识别，audioInfo 为 pcm、16000Hz、单声道、16bit，`maxAudioDuration: 30000`。用户停止时调用 `finish(sessionId)`，取消、切后台或退出时调用 `cancel(sessionId)`；按会话处理 onResult、onComplete 和 onError。会话结束释放音频内容，引擎在语音使用阶段结束后销毁。

候选采用 `09` 的字段与修订规则。可选会话热词取用户已有位置名及最近使用的物品名，过滤为每词 2—20 字，最多 200 个，保存在本地会话配置中。模型初始化、资源占用或权限需要处理时，P23 展示重试与继续输入。实际识别时间和修正成本按 A31 留证。

## 13. H14：静态快捷方式

在模块 profile 的 shortcuts_config 中定义四项：capture、search、dates、scan。通过 UIAbility metadata 的 `ohos.ability.shortcuts` 关联配置，各 wants 指向 EntryAbility，参数 `action` 使用上述固定枚举。onCreate、onNewWant 与卡片入口共用解析和导航。桌面最多展示四项，图标与标题使用系统符号及应用资源。[创建静态快捷方式](https://developer.huawei.com/consumer/cn/doc/doccenter-getting-started/typical-scenario-configuration)

四项依次进入 P03、P02、P12、P22，当前草稿遵循既有继续规则。应用所有入口读取当前数据；扫码和语音的设备可用性在进入任务时检查。个人账号与资格清单见 `16`，原生验证见 A32。
