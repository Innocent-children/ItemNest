# HarmonyOS 工程创建、素材配置与能力接入清单

项目状态：新项目尚未开发或开通平台服务，本轮只修订文档。工程师负责补齐工程、接入指定素材和实现 US1–US9；企业能力在文末仅保留未来规划，本次不准备材料、不接入、不进入当前检查表。平台接入按实际支持自动降级，详见 `capability-compatibility.md`。

## 用户提供文件核对

| 项目 | 已观察到的事实 | 结论与后续步骤 |
| --- | --- | --- |
| 应用身份 | `app_name` 为“我的家当”，bundleName 为 `com.imotong.itemnest`，均由用户指定 | 直接使用；注册和签名对应关系在需要接入时由工程师核对 |
| vendor | `example` | 是模板内容，不是已确认的 schema 错误；发布前取得真实发行者名称再替换 |
| 版本字段 | versionCode 1000000、versionName 1.0.0、buildVersion 1 | 本次未发现格式问题；建立后续递增规则，不无故删除 buildVersion |
| 可选图标 | moving_girl / moving_buddy，引用两份 layered-image JSON | API 26 schema 有依据；保持命名，后续调用系统查询结果核对实际切换 |
| 指定图标 | 用户确认图标合法；background.png、foreground.png、buddy_foreground.png 均为 1024×1024 PNG | 使用现有文件，不重复要求权属、合法性或像素合规证明；实现后核对实际引用和显示 |
| 资源引用 | 两份分层 JSON 共用 background，分别引用两位前景；名称引用存在 | 静态引用可解析，不等于完成资源编译、UX 审核 |
| 动画素材 | 只有三张静态 PNG，没有两位形象的动画文件 | 后续制作待机、挥手、思考、庆祝、空状态；可先用原静态前景，不生成虚构素材路径 |
| 深浅色资源 | 只有 app_name，未有颜色/字号令牌 | 从 design.md 建立 base/dark 资源；深色形象是否另制按真实预览决定 |
| 根工程/模块 | 缺根与模块构建配置、依赖、entry、入口、路由、module.json5 | 使用当前官方 Stage 模板完善，不追溯旧工程 |
| Git 忽略 | `.gitignore` 有未限定路径的 `build-profile.json5` | 会忽略公共构建配置；后续调整规则并分离本机签名/路径 |
| 当前平台接入 | 提醒和端 A2A 的实际账号、签名及设备条件需在接入时核对 | 工程师先查公开资料；仅账号持有人必须操作时提出具体要求，不阻塞工程创建，企业能力不在当前核验范围 |

## 工程创建步骤

1. T001 锁定 DevEco、API 26 编译 SDK、配套 Hvigor/编译模式和实际设备；优先评估 API 20 起的兼容方案，核对依赖和模块装载后单独锁定最低版本，记录依据与可重复命令。
2. T002 从同版本官方模板建立公共根配置、构建入口、依赖和锁文件；调整忽略规则。若模板带 wrapper，完整保存其脚本和依赖文件，不手写半套 wrapper。
3. T003–T004 建立 `entry`、Stage `EntryAbility`、首页、路由、base/dark 资源和测试入口；根产品名/模块名统一，公共配置不包含绝对本机路径。
4. T005 直接接入用户指定的分层图标，保留源文件；记录用途与引用，安装后确认图标和启动窗显示正常，不另开素材合法性或合规证明任务。
5. T006 按实际实现进度补扩展、权限和入口声明；P2 已纳入完整范围，在对应功能接入时声明必要权限，不提前声明空组件或网络权限。
6. T007 在代理提醒和端 A2A 接入阶段核对具体条件，不作为 T008 最小工程构建安装的前置条件。T008 记录构建、安装和本机签名说明；本轮不运行构建。

## 配置与验证矩阵

| 配置/能力 | 待补文件或适配位置 | 声明与使用要求 | 真机通过条件 |
| --- | --- | --- | --- |
| 启动、设备与资源 | `entry/src/main/module.json5`、base/profile 路由、base/dark/element | phone/tablet；入口、label、启动窗资源完整，不误覆盖应用图标 | 冷启动、深浅色、折叠切换、键盘和安全区正确 |
| 材质/悬浮底栏/HDS/光效/动效 | `platform/CapabilityService.ets`、`components/` | 接口版本、SysCap 与专用检测分别保护；新版组件不可用时不创建；UIMaterial.state 按实际接入声明 | 三档材质、基础 ArkUI 回退、减少动画、页面隐藏停效；冷启动不调用不支持的接口 |
| 触感与无障碍 | `platform/AccessibilityAdapter.ets`、`platform/HapticAdapter.ets` | H1–H7 跟随系统；读屏标签、字号和触控区 | 读屏聚焦提示条，10 秒可撤销，大字号完整可达 |
| 图标切换 | `AppScope/app.json5`、`platform/AppearanceAdapter.ets` | 名称精确对应 alternateIcons；调用后核对系统实际状态 | 两种图标和形象一致，失败保持实际选择 |
| 文字识别/分割/检测/图搜 | `platform/VisionAdapter.ets` | 每项分别检测，全部端侧；不可用无云替代 | 候选须点击；无到期标签不误用生产日期；索引与隐私开关一致 |
| 文档扫描/大图分析 | `platform/VisionAdapter.ets` | 使用对应 Kit 和版本支持范围，区分 P1/P2 | 扫描件保存，拒绝/不支持可手工添加照片 |
| 语音/文本分析/朗读 | `platform/SpeechAdapter.ets`、`domain/TextParser.ets` | 麦克风在首次使用请求；端侧模型检查；应用句式先解析 | 离线识别、歧义候选、中文日期、权限拒绝可解释 |
| 问问家当本地查询 | `domain/LocalQuestionService.ets`、`components/AnswerCard.ets` | 直接显示查询结果与依据，不导入 localChatModel；模型生成仅在文末选做 | 数量/位置/日期与依据一致，无模型仍完整，无生成进度或无效引导 |
| 智能体端 A2A | `platform/AgentAdapter.ets`、注册资料 | 工程师核对独立接入条件及实际设备支持，平台标识真实有效；不自行归为企业专属 | 获准时查询与修改候选可用；未获准记录具体平台阻塞并保留本地查询，不能仅因原 P1 而自行延期 |
| W1–W6 卡片 | extensions、base/profile/form_config.json、module 声明 | 全尺寸、主题、编辑、互动扩展；刷新时刻是调度请求 | 各尺寸、单色、失效目标、W6 并发扣减与撤销通过 |
| 代理提醒 | `platform/ReminderAdapter.ets`、module 权限 | PUBLISH_AGENT_REMINDER、通知授权、额度、签名与资格分别核对；一次提醒、同日合并 | 同日合并、窗口受限、重复启动不重复提醒；拒绝通知不丢待办 |
| 扫码 | `platform/ScanAdapter.ets` | 默认扫码与自定义扫码权限不同；自定义首次请求 CAMERA | 条码一件/多件/未知、连续扫码、照片读码、标签生成 |
| NFC | `platform/NfcAdapter.ets`、module NDEF skill | NFC_TAG、TAG_FOUND、匹配 URI；覆盖前确认 | 本机标签读取/写入/改绑/失效，改名移动不失效 |
| 分享与碰一碰 | `platform/ShareAdapter.ets`、sendData skill | 只接收一张图或一段文本；任何发出渠道先审阅 | 图文收发、草稿打断、隐私字段选择和无可分享内容 |
| 文件与照片 | `data/PhotoStore.ets`、`platform/FilePickerAdapter.ets` | 文件/照片选择器最小授权；保存图库使用合适的系统授权机制，不预申请全库权限 | URI 读取、相机/相册取消、照片规范化、孤儿清理 |
| 便携/自动备份与短时任务 | `data/BackupService.ets`、`platform/BackgroundTaskAdapter.ets` | 系统短时任务有时限，不承诺后台无限完成 | 一致快照、取消、空间不足、提交前后中断 |
| 系统备份/换机 | BackupExtensionAbility、base/profile/backup_config.json | allowToBackupRestore、包含/排除路径、产品隐私开关生效 | 双设备 T11，照片和借还完整，提醒按本机重建 |
| 跨设备/联系人/日历 | 对应 platform 适配与权限 | 原 P2 纳入当前交付，按实现进度声明，使用时授权 | 拒绝授权及不支持不影响本机流程；接续不丢草稿，联系人可手填，归还日期保留在应用内 |

## 素材接入与效果验证

- 按用户指定直接使用现有图标，不重制图标、不重复请求权属或合法性确认。`docs/asset-manifest.md` 只记录现有文件用途、引用，以及新增动效的制作方式。
- 工程负责资源可编译、没有被模块配置误覆盖，安装后显示的是指定图标；启动窗和应用内插画按各自布局正确展示。显示验证不作为再次审查用户图标合规的理由。
- 形象动效由工程师按设计选择受支持的实现方式，每段不超过 3 秒，可循环段首尾衔接，提供静态与减少动画表现；不生成不存在的素材路径。

## 规范结论的使用范围

工程完整性、资源正确接入和运行兼容由工程师负责。`vendor` 的真实发行者信息无法推导时，仅在需要该信息的发行步骤提出；不阻塞工程和业务开发。各项在相应实现阶段进行构建、签名安装和效果验证，当前均未执行，不能以缺少结果反过来要求先验证再创建工程。

## 最后：企业受限能力接入（可选，默认不执行）

对应 US10 / T148–T154，只有用户后续选做时才准备材料、申请与接入。未选不提供空扩展、可启用开关或引导，不作为 T007 或核心发布验收的依赖；规则来源见 research.md 的 RSC-10。

| 可选能力 | 配置目标 | 选做前条件 | 选做后的验收 |
| --- | --- | --- | --- |
| 小艺意图/实体/意图共享 | IntentAdapter、IntentSharingAdapter、insight_intent.json | Intents Kit 企业主体、能力申请与注册，核对开放垂域 | I1–I6/E1、预填确认、查询不超过十条、关闭后拒读与清理、位置隐私；QV-10 |
| 模型生成式问答 | LocalQaAdapter、AnswerCard | localChatModel 仅企业可申请且仅 PC/2in1；当前手机/平板不支持，另核 INTERNET 权限，扩范围需新指令 | 事实一致、流式 M24、模型不可用或关闭时回到查询结果，无云替代；QV-10 |
| LV1–LV3 实况窗 | LiveViewAdapter、扩展和资源 profile | 推送路径需企业账号；个人本地路径商用权益未核实；分别核对三个场景、自定义展开区和锁屏权益 | 业务/胶囊/展开/锁屏一致，进程结束自动结束，购物四小时关闭，草稿会话可恢复；QV-10 |

资格或设备不符时保留“可选未实施/未验证”，不勾选通过，也不影响核心版本。代理提醒、普通卡片、官方系统备份与换机不因本表被后置。
