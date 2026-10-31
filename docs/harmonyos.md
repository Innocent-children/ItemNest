# 我的家当 · HarmonyOS 能力清单

本文列出应用使用的全部 HarmonyOS 7（API 26）能力：每项能力用来做什么、需要哪些声明和平台配置、设备不支持时怎么降级。目标是让应用从视觉到入口都长在系统里：系统材质与光效、悬浮底栏、端侧 AI、小艺与智能体、实况窗、全套服务卡片、碰一碰分享。能力名称和接口均已对照本机 DevEco Studio 的 API 26 SDK（`HarmonyOS 26.0.0.105`）核实。视觉和动效的具体参数见 [design.md](design.md)，对应的功能需求见 [request.md](request.md)。

## 使用原则

- **先判断，再使用。** 每项能力在调用前检查设备是否支持：系统能力用 `canIUse('SystemCapability.xxx')`，接口自带判断的用接口（例如 `uiMaterial.isImmersiveMaterialSupported()`、`scanCore.isCustomScanSupported()`、`AgentController.isAgentSupport()`、`liveViewManager.isLiveViewEnabled()`）。不支持时按本文的降级方式处理，不弹错误。
- **系统能力是入口和渠道。** 卡片、实况窗、通知、小艺、系统搜索任何一个不可用，应用内的搜索、待办、记下照常完整。
- **数据只在本机。** 所有 AI 能力都用端侧模型，不申请网络权限，不上传照片、语音和物品信息。
- **外部改动要确认。** 来自小艺、智能体、链接、NFC、通知、分享的改动，先打开应用内预填的面板，用户确认后才保存（R34）。

## 能力总表

| 领域 | 能力（Kit · 模块） | 在应用里做什么 | 需求 |
| --- | --- | --- | --- |
| 界面材质 | ArkUI `uiMaterial.ImmersiveMaterial`、通用属性 `systemMaterial` | 底栏、标题栏、搜索框、面板、菜单、弹窗、提示条的玻璃质感，带光感反馈和交互形变 | VIS-01 |
| 悬浮底栏 | ArkUI `Tabs.barFloatingStyle` | 悬浮玻璃底栏，按屏幕宽度分档，开启左右手适配 | NAV-01 |
| 标题栏 | ArkUI `Navigation` 标题栏 `systemMaterial` 与 `scrollEffectOptions`；UI Design Kit `HdsNavigation` | 滚动时标题栏渐进模糊、大标题收起 | VIS-01 |
| 光效 | UI Design Kit `hdsEffect`（`pointLight`、`pressShadow`、`shaderEffect`）、`HdsVisualComponent` 边缘流光场景 | 卡片和按钮的点光源、按压光影，AI 处理中的流光 | VIS-02 |
| 组件 | UI Design Kit `HdsSnackBar`、`HdsActionBar`、`HdsListItem`（滑动操作）、`HdsSideBar` | 撤销提示条、物品页操作栏、列表滑动操作、宽屏侧栏 | NAV-03、ITEM-03、TODO-03、NAV-05 |
| 动效 | ArkUI `geometryTransition`、`NumericTextTransition`、`SymbolGlyph` 符号动效、`Particle`、`List.chainAnimation`、`motionBlur`、`Text.shaderStyle` | 共享元素转场、数字滚动、图标动效、庆祝粒子、列表链式回弹、渐变文字 | VIS-03 |
| 触感 | Sensor Service Kit `vibrator` 预设 | 保存、完成、阻止、切换时的触感反馈 | VIS-04 |
| 左右手 | Multimodal Awareness Kit `motion`（操作手识别）、`FloatingTabBarStyle.adaptToHandedness` | 悬浮底栏和＋按钮随操作手偏移 | NAV-01 |
| 文字识别 | Core Vision Kit `textRecognition` | 从包装照片识别名称、生产日期、保质期、到期日 | AI-01 |
| 主体分割 | Core Vision Kit `subjectSegmentation` | 生成去背景的物品抠图，作为卡片封面 | AI-02 |
| 物体检测 | Core Vision Kit `objectDetection` | 一张照片里框出多件物品，一次记下多件 | AI-03 |
| 以文搜图 | Core Vision Kit `textSearchImage` | 按"红色盒子"这类外观描述找物品照片 | AI-04 |
| 图像分析 | Vision Kit `visionImageAnalyzer`（`Image` 的 AI 分析） | 在大图里长按提取文字、抠出主体 | AI-05 |
| 文档扫描 | Vision Kit `DocumentScanner` | 扫描说明书、保修卡、发票，作为物品的扫描件 | AI-06 |
| 语音识别 | Core Speech Kit `speechRecognizer`（端侧中文模型） | 语音记下、语音查找 | AI-07 |
| 语音朗读 | Core Speech Kit `textToSpeech` | 朗读问问家当的回答 | AI-08 |
| 文本分析 | Natural Language Kit `textProcessing` | 从语音和文字里抽取日期、人名，辅助解析"借给小王，下周三还" | AI-07 |
| 端侧问答 | Data Augmentation Kit `localChatModel` | 问问家当：用自然语言问"家里还有电池吗"，用本地模型组织回答 | AI-09 |
| 拼音 | Localization Kit `i18n.Transliterator` | 生成名称、别名、位置的拼音索引 | FIND-03 |
| 小艺意图 | Ability Kit `@InsightIntentEntry`、`@InsightIntentEntity`、`@InsightIntentForm`；Intents Kit `insightIntent.shareIntent` | 小艺查询和记录、系统搜索物品、在小艺里显示待办卡片、把常用操作分享给系统建议 | SYS-04、SYS-05 |
| 智能体 | Agent Framework Kit `FunctionComponent`、`AgentController`、`A2A` | 应用内拉起"我的家当"智能体；智能体通过 A2A 查询数据、生成待确认的改动 | SYS-06 |
| 服务卡片 | Form Kit `FormExtensionAbility`、`LiveFormExtensionAbility`、`FormEditExtensionAbility` | 六种桌面卡片，含互动卡片动效和卡片编辑页 | SYS-07 |
| 实况窗 | Live View Kit `liveViewManager`、`LiveViewCardExtensionAbility`、`LiveViewLockScreenExtensionAbility` | 备份恢复、连续记下、购物清单三种实况窗，含自定义展开区和锁屏样式 | SYS-08 |
| 提醒 | Background Tasks Kit `reminderAgentManager`；Notification Kit | 每天合并的到期和该还提醒 | TODO-07 |
| 后台任务 | Background Tasks Kit 短时任务 | 备份、恢复在退到后台后继续完成 | DATA-02 |
| 扫码 | Scan Kit `scanBarcode`、`customScan`、`generateBarcode`、`detectBarcode` | 扫码查找和记下、连续扫码、生成标签二维码、从照片里读出条码 | FIND-06、CAP-12、PLACE-07 |
| NFC | Connectivity Kit `nfcController` 与标签读写 | 写入和读取收纳标签，碰一碰打开位置 | PLACE-07 |
| 分享 | Share Kit `systemShare`、`harmonyShare` | 预览后分享；碰一碰把物品、清单发到另一台设备 | SYS-02、SYS-03 |
| 跨设备 | Service Collaboration Kit（跨设备拍照）；Ability Kit 应用接续 | 平板用手机拍照；手机记到一半到平板继续 | SYS-10 |
| 文件 | Core File Kit 文件选择器、`BackupExtensionAbility`；Media Library Kit 照片选择器 | 导出和选择备份文件、系统备份与换机迁移、选照片 | DATA-02、DATA-04 |
| 联系人 | Contacts Kit `contact.selectContacts` | 选择借用人 | LEND-07 |
| 日历 | Calendar Kit | 把约定归还日写进系统日历 | LEND-08 |
| 应用图标 | Ability Kit `bundleManager.setAlternateIcon` | 两种形象的应用图标切换 | SET-05 |
| 外观 | `ApplicationContext.setColorMode` | 跟随系统、浅色、深色 | SET-05 |
| 拖放 | ArkData 统一数据（拖放） | 宽屏下把物品拖到位置上完成移动 | NAV-05 |
| 状态保存 | ArkUI `NavDestination.onSaveState`/`onRestoreState` | 进程被回收后回到原页面和输入 | NAV-07 |
| 无障碍 | Accessibility Kit | 读屏、减少动画 | VIS-05 |

## 视觉与交互能力

材质、光效、动效的具体用法和参数见 [design.md](design.md)。这里只列声明和判断：

- 在 `module.json5` 的 `metadata` 中声明 `ohos.arkui.UIMaterial.state = enable`，让应用级沉浸材质默认开启。
- 用 `uiMaterial.isImmersiveMaterialSupported()` 判断设备能否绘制沉浸材质，用 `uiMaterial.getGlobalMaterialLevel()` 取得设备材质档位（`EXQUISITE`、`GENTLE`、`SMOOTH`），按 design.md 的设备分级开关效果。
- 悬浮底栏用 `barFloatingStyle` 设置三档宽度、侧边距、底边距、遮罩和 `systemMaterial`，`adaptToHandedness` 设为 true；键盘弹出时取消悬浮样式并隐藏底栏。
- 提示条使用 `HdsSnackBar`，操作类型用"文字加关闭"，文字按钮为"撤销"或"查看"。
- 系统"减少动画"开启时（`accessibility.isAnimationReduceEnabledSync()` 并监听变化），按 design.md 关闭非必要动效。

## 本地 AI

所有模型都在设备上运行。每项能力第一次使用前检查对应系统能力，并在设置里提供开关（R39）。

| 能力 | 输入与输出 | 不可用时 |
| --- | --- | --- |
| 文字识别 | 照片 → 文字行。应用从文字中找名称、生产日期、保质期和到期日，生成候选（R35） | 不显示识别候选，照片照常保存 |
| 主体分割 | 照片 → 主体掩膜，生成透明背景的抠图 PNG | 使用原图缩略图作为封面 |
| 物体检测 | 照片 → 多个物体的边框 | "一拍多件"入口不显示 |
| 以文搜图 | 物品照片入库（`insertImage`，范围固定为本应用），描述文字 → 相似照片和相似度 | 搜索不提供"按外观找" |
| 图像分析 | 大图中的文字和主体可以长按选取 | 大图只能缩放 |
| 文档扫描 | 拍摄并矫正文档，生成扫描件图片 | "扫描说明书"入口不显示 |
| 语音识别 | 中文语音 → 文字，端侧离线模型；需要麦克风权限 | 语音入口不显示 |
| 文本分析 | 文字 → 日期时间、人名等实体，辅助解析语音和小艺参数 | 只用应用自己的句式规则解析 |
| 端侧问答 | 问题和应用查出的事实 → 一句话回答，支持流式输出 | 只显示应用查出的结果卡片 |
| 语音朗读 | 回答文字 → 语音 | 不显示朗读按钮 |

**语音和文字的解析**：先用应用自己的句式规则识别"X 放在 Y""把 X 借给 Y""用掉 N 个 X"等说法，位置名和已有位置按名称和拼音匹配；日期和人名交给文本分析补充。解析结果只预填面板，由用户确认（R35）。

## 小艺、系统搜索与智能体

### 意图

| 编号 | 意图 | 参数 | 执行 |
| --- | --- | --- | --- |
| I1 | `JumpFunctionPage` | `pageId`：add、scan、camera、voice、search、todo、expiry、loans、shopping | 前台打开对应入口 |
| I2 | `ViewSearchPageLocal` | 无 | 前台打开"物品"栏目并聚焦搜索框 |
| I3 | `QueryStoredItems` | `kind`：items、place、expiry、loans、shopping；`name`：物品名或位置名，可空 | 后台查询，返回一句以位置开头的回答，例如"护照在 卧室 › 衣柜 › 上层"；最多列 10 条 |
| I4 | `RecordStoredItem` | `action`：add、consume、borrow、return；`name`、`quantity`、`unit`、`locationPath`、`expirationDate`、`counterpart`、`dueDate` | 前台打开预填的面板，回答"已准备好，请在应用里确认"，不直接保存 |
| I5 | `ViewStoredItem` | `item` 实体 | 前台打开物品页 |
| I6 | `ShowTodoCard`（`@InsightIntentForm`） | 无 | 在小艺里直接显示待办卡片（W2） |
| E1 | 物品实体 `itemnest_item` | `entityId`、`name`、`displayName`、`location` | 系统搜索按名称实时查询；"搜索结果显示位置"关闭时不带位置 |

I3 至 I6 在"允许小艺查询与操作"关闭时返回"请先在我的家当里开启小艺访问"。

### 意图共享

用户在应用里执行"查找某物""看看待办""用掉某物""打开购物清单"后，通过 `insightIntent.shareIntent` 把这次操作分享给系统，系统据此在小艺建议、负一屏等位置推荐。物品删除时用 `deleteEntity` 删除相关实体，"向系统分享常用操作"关闭时删除全部已分享的意图。

### 智能体

在小艺开放平台创建"我的家当"智能体，取得 `agentId`。

- **应用内入口**：问问家当的结果下方放 `FunctionComponent` 按钮"在小艺里继续问"，用 `AgentController.isAgentSupport()` 判断，不支持时不显示。
- **A2A 服务**：应用用 `createA2AServer` 提供智能体能力，支持三类任务：查询（物品位置、数量、到期、借出、购物清单）、生成待确认改动（记下、用掉、借出、归还，返回一个打开应用面板的链接）、读取待办摘要。所有任务受"允许小艺查询与操作"开关控制。

## 服务卡片

卡片数据和应用内待办使用同一套计算（R22、R23），数据变化后刷新，每天 00:01 和跨天时也刷新。所有卡片支持浅色、深色和系统主题的单色渲染模式。

| 编号 | 名称（注册名） | 尺寸 | 内容与操作 |
| --- | --- | --- | --- |
| W1 | 找东西（`widget_find`） | 2×2、2×4 | 搜索条、语音、＋、扫码；2×4 再显示 3 件最近动过的物品。点搜索条打开应用并弹出键盘 |
| W2 | 待办（`widget_todo`） | 2×2、2×4、4×4 | 角标数和最紧急的条目；4×4 按分组列出。点条目打开物品页，按钮打开对应的预填面板 |
| W3 | 借出未还（`widget_loans`） | 2×2、2×4 | 按借用人汇总件数和最早借出天数，点人打开待办的借出分组 |
| W4 | 一个位置（`widget_place`） | 2×2、2×4 | 用户在卡片编辑页选一个位置（例如药箱），卡片列出里面的物品和数量 |
| W5 | 一件物品（`widget_item`） | 1×1、2×2 | 用户选一件物品（例如护照），显示抠图封面和位置 |
| W6 | 消耗品余量（`widget_stock`） | 2×2、2×4 | 用户选几件消耗品，显示在手数量和"用掉 1"按钮；点按钮直接记一笔，卡片上 5 秒内可撤销（R34 的例外），并播放越出卡片边界的数字动效 |

- W4 至 W6 用 `FormEditExtensionAbility` 提供卡片编辑页，选择位置、物品或消耗品。
- W6 用 `LiveFormExtensionAbility` 实现互动卡片，点"用掉 1"后调用 `formProvider.requestOverflow` 播放不超过 1.2 秒的越界动效（系统上限 3.5 秒）。其余卡片的按钮打开应用内预填的面板。
- 卡片出错时显示"暂时无法更新，点开重试"，不显示更新时间。

## 实况窗

三种实况窗都使用"进度"（`PROGRESS`）场景，只在用户主动开始的操作中出现，结束后自动关闭；生命周期设为应用进程结束时自动结束。

| 编号 | 场景 | 何时出现 | 内容 | 点击 |
| --- | --- | --- | --- | --- |
| LV1 | 备份与恢复 | 备份、恢复预计超过 3 秒 | 标题"正在备份"或"正在恢复"，进度胶囊显示百分比 | 回到"我的 › 数据" |
| LV2 | 连续记下 | 开启连续记下后离开应用 | "正在整理 书房 › 抽屉 · 已记 12 件"，文字胶囊显示件数 | 回到记下面板 |
| LV3 | 购物清单 | 在购物清单点"去购物" | 自定义展开区（`LiveViewCardExtensionAbility`）列出未买的前 5 项；进度胶囊显示"已买 3/7"；锁屏样式（`LiveViewLockScreenExtensionAbility`）同样列出清单 | 打开购物清单 |

- 用 `liveViewManager.isLiveViewEnabled()` 判断用户是否允许实况窗；不允许或平台未开通时，应用内照常显示进度和清单。
- LV3 在全部买完或用户点"结束购物"时关闭；超过 4 小时没有更新也关闭。

## 提醒与通知

- 使用系统代理提醒（`reminderAgentManager`），声明权限 `ohos.permission.PUBLISH_AGENT_REMINDER`，需要通过平台的代理提醒使用资格。
- 每个提醒日一条通知（R24）：单件时标题"牛奶明天到期"，正文"冰箱 › 冷藏层 · 2 盒"；多件时标题"3 件物品快到期"，正文列出前 3 个名称，借出到期并在同一条里写"小王的电钻今天该还"。
- 点通知：单件打开物品页，多件打开待办。
- 首次填写到期日时询问开启（R25），开启时请求通知授权。
- 发布失败（包括错误码 1700002 这类资格问题）时，在"我的 › 提醒"显示一句原因；待办、角标和卡片照常显示（R22、R23）。

## 扫码与 NFC

| 能力 | 用法 |
| --- | --- |
| 默认扫码界面（`scanBarcode`） | 扫码查找、扫码记下的单次扫描，不需要相机权限 |
| 自定义扫码界面（`customScan`） | 连续扫码记下：玻璃取景框和扫光动效，每扫到一个码就加一条待确认物品；需要相机权限，`isCustomScanSupported()` 为假时改用默认界面逐个扫 |
| 生成二维码（`generateBarcode`） | 生成标签二维码图片，叠加位置名和路径后保存到图库或分享 |
| 照片读码（`detectBarcode`） | 物品照片里有条码时自动填入条码候选 |
| NFC 读取 | 系统读到 NDEF 标签时按 `itemnest://location/{token}` 打开位置页；应用内"绑定已有标签"时前台读取 |
| NFC 写入 | 把链接写成 NDEF URI 记录；写入会覆盖标签原有内容，写前提示 |

## 分享与跨设备

- **系统分享**：物品卡片、位置清单、借出清单、购物清单、提醒对方的文字，都先在分享预览里确认内容和可选项（位置、备注、借用人、照片），再调起系统分享面板（`systemShare`）。
- **碰一碰分享**：分享预览、物品页、位置页、购物清单打开时注册 `harmonyShare` 碰一碰事件；两台设备碰一下，就把当前内容（图片卡片加文字）发给对方。没有内容可分享时按接口要求返回拒绝原因。
- **接收分享**：声明接收一张图片或一段文字（`ohos.want.action.sendData`），打开预填的记下面板。
- **跨设备拍照**（P2）：平板上记下物品时，可以选择用附近手机的相机拍照（Service Collaboration Kit）。
- **应用接续**（P2）：手机上记到一半的物品或打开的物品页，可以在平板上继续。

## 数据安全

- **便携备份**：用文件选择器保存和选择 `.itemnest` 备份包，格式见 data.md。
- **短时任务**：备份、恢复开始时申请短时任务，退到后台后继续完成；任务被系统结束时，恢复的事务回滚，当前数据不变。
- **系统备份与换机**：在 `backup_config.json` 中开启 `allowToBackupRestore`，实现 `BackupExtensionAbility`：备份时用 RDB 备份接口生成一致的数据库副本，连同照片目录交给系统；恢复时校验数据库，替换后按 R24 重新安排提醒。
- **自动备份**：应用在前台、距上次自动备份超过 7 天时，在后台生成备份包，保留最近 3 份。

## 声明与平台配置清单

| 位置 | 内容 |
| --- | --- |
| `AppScope/app.json5` | 项目已有，直接使用：包名 `com.imotong.itemnest`、应用名 `$string:app_name`、默认图标 `$media:layered_image`，`alternateIcons` 声明 `moving_girl`（女生形象）和 `moving_buddy`（男生形象）两种图标；切换图标时调用 `bundleManager.setAlternateIcon` 传入这两个名字 |
| `module.json5` · 设备 | `phone`、`tablet` |
| `module.json5` · 元数据 | `ohos.arkui.UIMaterial.state = enable` |
| `module.json5` · 入口技能 | 桌面入口；`itemnest://item`、`location`、`function` 链接；NFC `TAG_FOUND`（`tag-tech/Ndef` 与 `itemnest://location`）；接收图片和纯文本分享 |
| `module.json5` · 扩展 | 卡片 `FormExtensionAbility`、`LiveFormExtensionAbility`、`FormEditExtensionAbility`；实况窗 `LiveViewCardExtensionAbility`、`LiveViewLockScreenExtensionAbility`；`BackupExtensionAbility` |
| 权限 | `ohos.permission.PUBLISH_AGENT_REMINDER`；`ohos.permission.NFC_TAG`；`ohos.permission.MICROPHONE`（语音，使用时申请）；`ohos.permission.CAMERA`（连续扫码，使用时申请）；跨设备能力需要的分布式权限只在实现 P2 时声明 |
| 资源配置 | `form_config.json`（六种卡片）、`insight_intent.json`（I1、I2 与功能入口）、`backup_config.json`、启动窗配置 |
| AppGallery Connect | 代理提醒使用资格；实况窗权益与 `PROGRESS` 场景，以及自定义展开区和锁屏样式的使用；推送服务（实况窗依赖） |
| 小艺开放平台 | 意图与实体注册、调试账号；智能体创建与 A2A 接入；功能搜索接入 |

平台配置是否生效，以签名包在真机上的端到端结果为准：编译通过、声明存在、应用内开关开启，都不代表平台已经开通。

## 设备验证清单

每项能力都在至少一台支持和一台不支持（或关闭授权）的设备上验证：

- 沉浸材质三档设备效果与降级；悬浮底栏左右手适配；减少动画开启后的表现。
- 文字识别、主体分割、物体检测、以文搜图、图像分析、文档扫描、语音识别、端侧问答、朗读：可用时的结果，不可用时入口隐藏。
- 六种卡片的各个尺寸、深浅色和单色模式；W6 的直接用掉与撤销；越界动效。
- 三种实况窗的胶囊、展开区、锁屏样式；未开通时的应用内表现。
- 合并提醒的内容与跳转；未授权和代理提醒失败时的待办完整性。
- 小艺 I1 至 I6、系统搜索实体、意图共享、智能体入口与 A2A 任务。
- 扫码三种方式、NFC 读写、碰一碰分享、系统分享收发。
- 便携备份与恢复（含取消、空间不足、文件损坏）、自动备份、系统换机。
