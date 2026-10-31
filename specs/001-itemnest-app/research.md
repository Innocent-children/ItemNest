# Research: 技术核对与设计决定

日期：2026-10-31。证据来自当前工作区、本机 SDK 和华为官方资料；没有阅读 Git 历史，没有编译或运行应用。

## 证据等级

“文件/SDK 已确认”只描述本地内容；“官方限制”以所列当前官方文档为依据；“用户决定”记录明确选择；“设计选择”是本套方案；“待验证”必须在后续设备或平台任务取证。`docs/harmonyos.md` 自述核对过 SDK，这一自述不等于本次真机测试。

## RSC-01：工程和平台版本

**Decision**：以 API 26、Stage、单 `entry` 模块创建新工程，保留中文名、项目名与包名。

**Evidence**：当前只有六份 `docs/`、`AppScope/app.json5`、字符串、两份分层图标 JSON 和三张 PNG。`/Applications/DevEco-Studio.app/Contents/sdk/default/sdk-pkg.json` 声明 `apiVersion: 26`、`version: 26.0.0.105`、`stage: Release`。

**Rationale**：API 26 与需求文档匹配，不能按较老版本知识认定这些能力不存在。根构建配置、模块、入口和测试均缺失，应作为新建任务。

**Alternatives considered**：更低 API 版本不能覆盖当前设计要求，因此以 API 26 规划新工程。

**Pending**：DevEco、Hvigor、ArkTS 编译配置、目标真机和签名由 T001–T004 锁定。

## RSC-02：应用配置与图标

**Decision**：以用户指定的应用身份和素材包创建资源配置，发布前填写真实发行者并通过 Image Asset 与 UX 检查。

**Evidence**：本机 `openharmony/toolchains/modulecheck/app.json` 定义 `alternateIcons`、`vendor`、`buildVersion`；当前 `buildVersion: "1"` 不是非法字段。`@ohos.bundle.bundleManager.d.ts` 有 API 26 的 `setAlternateIcon(alternateIconName: string)`。三张 PNG 均为 1024×1024；分层资源引用完整，视觉检查可见两位形象和浅色背景。

**Rationale**：尺寸和结构具备基础条件，但不能据此声称已经符合全部桌面图标规范。`vendor: "example"` 是模板值，真实发行者名称仍待确认。图标主体边距、背景透明度、系统遮罩裁切、启动窗和素材权属均需验收。

**Alternatives considered**：删除 `alternateIcons` / `buildVersion` 或立即重制素材都不采用；没有证据支持删除，本次也未授权素材开发。

**Official source**：[应用信息与图标配置 FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/appgallery-kit-faq-0010)。要求前景/背景分层、1024×1024、不预裁圆角，背景不透明；模块图标配置可能覆盖应用级配置。DeepSeek 找到的旧 FAQ 正文链接返回 404，已按优先级改用 Exa 找到此官方入口。

## RSC-03：材质、端侧问答与 A2A

**Decision**：根据需求文档选择 API 26，统一能力检测；核心问答直接显示查询事实，企业受限的模型生成后置至 US10。端 A2A 与 Intents Kit 分开核验，不把两者主体限制混同。

**Evidence**：本机 `@ohos.arkui.uiMaterial.d.ts` 定义三档材质与支持检查；`hms/ets/api/@hms.data.localChatModel.d.ts` 标注端侧问答并提供 `chat`；`@hms.ai.A2A.d.ts` 提供 `createA2AServer`。

**Rationale**：声明存在只说明能针对 SDK 编写，不能证明目标设备有模型或平台已开通。后续官方核查已确认 localChatModel 仅企业可申请且仅支持 PC/2in1，不能作为手机/平板核心方案；详见文末 RSC-10。官方系统服务按所选范围正常接入，设备和资格仍须核验，不额外增加数据离机确认。

**Alternatives considered**：接云端模型或自建服务端不采用，超出离线核心范围。问答不可用时仅显示数据库查询结果。

## RSC-04：提醒额度和提醒频率

**Decision**：用户已确认按 R24 执行一次提醒、同日合并；有限滚动窗口内安排提醒，不在提前窗口内每天重复。

**Evidence**：`@ohos.reminderAgentManager.d.ts` 将 `1700002` 定义为提醒数量超限。[官方错误码说明](https://developer.huawei.com/consumer/cn/doc/harmonyOS-references/errorcode-reminderagentmanager) 解释未获使用权限时配额为 0；API 26 普通应用配额最多 64 条，旧版本最多 30 条，另有系统总量限制。

**Rationale**：不能仅凭 `1700002` 判定资格失败，也不能认定需求文档举资格问题毫无依据。诊断需区分通知授权、权限/签名、应用额度与平台资格。读取实际条件并控制窗口，不安排无限期提醒。

**Pending**：窗口建议最多 30 个未来提醒日，且不超过实测可用配额；该数值是实现选择，不是 API 上限。跨天、提醒触发和进入应用时对账；本机去重记录避免每次启动都再次安排“已经提醒过”的同一事件。同一事件不因重新启动应用、刷新计划或内容更新而再次通知。

## RSC-05：卡片不是实时镜像

**Decision**：使用相同查询快照和规则；应用写入后主动刷新，卡片重新可见或应用启动时对账，记录投影版本。

**Evidence**：`forms.json` 允许 `scheduledUpdateTime: "HH:mm"`；`@ohos.app.form.formProvider.d.ts` 的下次刷新最短为 5 分钟。[官方卡片被动刷新说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/arkts-ui-widget-passive-refresh) 列出调度限制，每日定点更新配合 `updateDuration: 0`。

**Rationale**：00:01 是可配置的期望时间，不是应用能保证的精确后台执行时间。“同一时刻数量一致”应修订为“同数据版本同口径，重新获得运行机会时对账”。不新增每分钟保活定时器。

## RSC-06：实况窗准入和生命周期

**Decision**：LV1–LV3 整组移至文末 US10，可选、默认不执行，不是连续记下、购物或备份的依赖。选做后才核对正式权益和各场景准入；API 26 显式设置随应用终止而自动结束的生命周期。

**Evidence**：`@hms.core.liveview.liveViewManager.d.ts` 的 `PROGRESS` 子场景列举 UPLOAD、DOWNLOAD、IMPORT、EXPORT、BACKUP、RECOVER；不能据此保证购物和连续整理准入。生命周期默认 `STOP_BY_APP`，需求文档期望的进程结束自动结束对应 `AUTO_STOP_WHEN_APP_TERMINATE`。

**Rationale**：不把平台权益当作 SDK 编译参数，也不保证纯本地应用被回收后仍持续更新。[官方 Push 更新实况窗说明](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/liveview-update-by-push) 明确本地更新依赖进程，远程 Push 是另一条需要服务端的链路。本方案不加入远程 Push 服务端。

**Pending**：官方已明确推送路径要求企业账号并先开推送服务；个人本地路径正式商用资格仍无明确依据，不推断为已支持。仅在选做后由 T148/T153 核验三个场景、自定义锁屏和签名设备证据。不引入服务端替代，核心保留应用内体验。

## RSC-07：空值唯一、份合并与历史引用

**Decision**：唯一键按空位置、空到期日归一化；合并时迁移借出来源，保留历史显示快照，撤销时一起核对引用版本。

**Rationale**：普通复合唯一索引不能直接保证 SQL 空值相等。份清零后仍可能被已归还借出和历史动态引用，直接级联删除会丢历史。具体设计见 `data-model.md` 的 DM-01–DM-04。

**Alternatives considered**：只在 UI 检查重复份、合并后删除借还记录、数量负数时强制归零均不采用，会隐藏真实不一致。

## RSC-08：文件与数据库恢复边界

**Decision**：导出显式白名单表；恢复照片先写完新的代际目录，事务中替换数据并切换照片引用，提交后才清理旧代目录。

**Rationale**：数据库事务不包含文件移动。原 R40 的暂存/替换描述不足以保证提交后被系统结束时照片可用。详见 `contracts/backup.md`；只补足已经明确要求的备份中断、取消与文件安全，不扩展基础设施故障系统。

**Alternatives considered**：事务提交后才把唯一照片副本移到正式目录不采用，会出现新数据引用未完成文件的窗口。

## RSC-09：需求文档差异的处理

- 需求标题实际 119 条，优先级统计与 `request.md` 表一致；仅 `product.md` 写成 120。
- R5 允许清理零份，故“物品分成一到多份”不能理解成始终至少一份。
- `experience.md` 快到期行统一写“用掉”，但 R18 禁止普通物品用掉；本套按类型显示“改日期”或“不再提醒”。
- `FIND-09` 与交互页对答案卡第二操作不完全一致；建议普通物品“移动/借出”、消耗品“用掉 1/补货”，待用户查看建议。
- `R17` 的“每次写入更新 last_activity_at”若包含打开物品页和资料编辑，会改变“最近动过”含义；建议仅业务活动更新，浏览只改 `last_viewed_at`。
- 用户已确认官方系统能力正常接入，以及一次提醒、同日合并；规格、数据模型和任务同步采用这两项决定。

以上差异均在新规格中说明，原 `docs/` 保持不变。补充建议和需用户回答的问题见 `open-questions.md`。

## RSC-10：企业受限能力后置为可选（2026-10-31 用户决定）

**Decision**：用户为个人开发者，可能不实施这些能力，但要求保留在 SpecKit 最后。SYS-04/SYS-05、AI-09 模型生成部分、SYS-08 统一进入文末 US10 / T148–T154，可选、默认不执行、不阻塞核心发布。SYS-04 原 P0 明确转为可选；本地查询结果和连续记下、购物、备份主流程保留。

| 能力 | 官方依据和准确边界 | 本套处理 |
| --- | --- | --- |
| Intents Kit | [官方简介](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/intents-introduction)明确仅面向企业开发者，个人无法申请和注册意图能力；覆盖小艺对话、搜索和建议分发 | SYS-04（含 I6/E1）与 SYS-05 后置可选，不作为核心隐私页或卡片依赖 |
| localChatModel | [端侧问答模型指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/dataaugmentation-localchatmodel)明确仅企业可申请、仅 PC/2in1，并要求 INTERNET 权限 | AI-09 仅生成部分后置；当前手机/平板与无网络权限范围不能直接接入，取得企业账号也不能解决设备限制 |
| Live View Kit | [官方 FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-liveview-2?docScope=all)明确推送实况窗需企业账号并先开推送服务；这不能单独证明所有本地用法均企业专属，也不能证明个人已可商用 | 依用户决定将 SYS-08 整项后置可选，本地路径资格与 LV2/LV3 准入仅在选做时核验 |
| 代理提醒 | [现行指南](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/agent-powered-reminder)要求 AGC 申请、应用分类/场景材料及重新生成 Profile 手动签名，未列企业主体限制；临期提醒在开放场景内 | 保留 TODO-07 及资格核验，不因旧邮件模板填写企业名称而后置 |
| 端 A2A / FunctionComponent | [端 A2A 创建指南](https://developer.huawei.com/consumer/cn/doc/doccenter-celia/device-a2a-quickstart-0000002733266338?docScope=all)给出已在 AGC 发布应用、关联应用、AgentExtensionAbility、真机白名单等条件，未列仅企业；不据此声称个人已获准 | SYS-06 保留 P1，T007/T108 独立核验账号入口及审核；不依赖企业 Intents Kit 或 localChatModel |

**Evidence scope**：本次核对官方公开指南与 FAQ，先使用 DeepSeek；部分小艺页面抓取失败或信息不足后改用 Exa 核对。未登录开发者账号、未申请权益、未运行真机。

**Acceptance**：核心发布检查 65 条必需 P0 和选定非企业扩展 P1；119 条原需求保持追溯，企业可选项记“可选未实施”，不等同于测试通过。US10 选做后才要求所选能力通过 QV-10。未选扩展的权限、空组件、可启用开关和使用引导不提前加入核心版本。
