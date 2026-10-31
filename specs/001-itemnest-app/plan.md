# Implementation Plan: 我的家当完整应用

**Branch**: 本次未创建或切换 Git 分支；SpecKit 活动特性 `001-itemnest-app` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/001-itemnest-app/spec.md`

## Summary

为新项目“我的家当”从零创建 HarmonyOS 原生应用，以用户提供的六份需求文档和 `AppScope/` 素材包为输入。采用单个 Stage `entry` 模块，ArkTS/ArkUI 负责页面，业务服务统一管理数量、借还、待办和撤销，ArkData 保存本地数据，系统能力通过适配层接入。按 119 条需求及其发布优先级规划工程和功能，不预设项目业务实现。

本轮只修订文档。后续实施按用户要求完整交付 US1–US9 非企业功能，原 P0/P1/P2 仅保留追溯与排序，不自行延期。企业受限能力仍保留在文末 US10，本次不实施、不申请、不进入当前检查表。以下工程与任务尚未执行。

## Technical Context

**Language/Version**: ArkTS；API 26 SDK 的实际编译模式和语言限制在 T001 核定，不混用不兼容的 ArkTS 状态管理模式。

**Primary Dependencies**: ArkUI、Ability Kit、ArkData；按已选功能接入 UI Design Kit、Core Vision/Speech、Natural Language、Scan、Form、Share、Background Tasks、Backup 等 Kit。Intents、Data Augmentation 的 localChatModel 和 Live View 只在 US10 对应项选做后引入；核心不导入这些模块或声明空扩展。版本随已选 SDK 和 DevEco 配套工具锁定，不凭空指定包版本。

**Storage**: S3 级 `nest.db`、`nest_settings`、私有照片和备份目录；无应用服务端。

**Testing**: Hypium 本地单测与 `ohosTest` 设备测试，DevEco 静态检查、HAP 构建和签名真机走查；具体命令以新建工程的 Hvigor 任务清单为准。

**Target Platform**: API 26 为编译与增强体验基线；phone、tablet 与折叠屏窗口形态。T001 优先评估 HarmonyOS 6.0 / API 20 起的兼容方案，核对核心依赖后锁定最低版本，不能把编译 SDK 当成最低运行版本。本机 SDK 声明 `26.0.0.105 / Release` 不证明所有设备具备全部能力；兼容方案见 `capability-compatibility.md`。

**Project Type**: HarmonyOS 原生移动应用。

**Performance Goals**: 首帧优先显示搜索；遵守 T1–T15 点击目标；列表超过 300ms 才显示加载文字；持续光效最多一个、页面隐藏即停。真机记录启动、搜索和滚动采样，不虚构硬性性能数值。

**Constraints**: 核心离线、无账号和网络权限；外部改动确认；正确处理业务并发与跨扩展入口；禁止查看受限 Git 历史；本次文档后停止。

**Scale/Scope**: 119 条原需求（66 P0、43 P1、10 P2），40 条业务规则，15 个成功任务，7 个推入式页面和 6 种卡片。SYS-04 从首发必需改为可选后，核心必需 P0 为 65 条；三种实况窗及其他企业受限项均在末尾 US10。T13 的模型生成、T14 的锁屏展示按选做范围验收。没有用户数据规模指标，不以假设容量替代压测结果。

## Constitution Check

| 原则 | 研究前 | 设计后 | 证据或条件 |
| --- | --- | --- | --- |
| 当前文档基线与历史限制 | 通过 | 通过 | 不查询 Git 历史，保留需求文档与素材 |
| 数据保护与外部确认 | 通过 | 通过 | 官方系统能力正常接入，产品隐私开关及外部修改确认照常实现 |
| 数量、借还和撤销一致 | 通过 | 通过 | `data-model.md`、`contracts/domain.md` |
| 就地完成与原生体验 | 通过 | 通过 | 统一面板、设计目录与 US8 |
| 自主决策、能力检测与降级 | 通过 | 通过（设计） | 兼容策略已明确；资格与真机结果留到相关任务，未运行不计通过 |
| 可追溯验收与文档边界 | 通过 | 通过 | 需求逐条映射，实施任务全部未勾选 |

用户已确认一次提醒、同日合并，以及官方系统能力正常接入；两项不再是实施阻塞条件。企业受限能力已明确后置为可选，资格核验与平台申请也一并后置，不能由 S0 或 US7 提前触发。代理提醒和 SYS-06 端 A2A 的主体与权益分别核验。本次只交付文档，不调用实施工作流。

工程创建、依赖配置、签名方式和技术兼容选择由工程师查证后直接落实；指定应用名、包名和图标不再重复确认。缺少某项平台条件时，只记录并处理该项，不阻塞独立的工程与业务工作。检查表用于确认要求写清楚，不能要求开工前取得全部设备验收结果。

## Project Structure

### Documentation (this feature)

```text
specs/001-itemnest-app/
├── README.md
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── platform-readiness.md
├── capability-compatibility.md
├── requirements-map.md
├── open-questions.md
├── contracts/
│   ├── domain.md
│   ├── external-entry.md
│   └── backup.md
├── quickstart.md
├── tasks.md
└── checklists/
    ├── requirements.md
    └── platform.md
```

### Source Code (repository root；实施目标)

```text
AppScope/                         # 用户提供的配置和三张 PNG；按用途完成资源配置与验收
build-profile.json5               # 待补：公共产品/模块配置
hvigorfile.ts                     # 待补：根构建入口
hvigor/hvigor-config.json5        # 待补：配套构建工具版本
hvigorw / hvigorw.bat             # 如对应官方模板提供，则一并保留
hvigor/                          # 包含该模板所需 wrapper 文件，避免只保留脚本
hvigor/ohos-signing-config.json5  # 仅为本机私有配置的示意，不要求此名称或跟踪密钥
oh-package.json5 / oh-package-lock.json5
entry/
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── src/
    ├── main/
    │   ├── module.json5
    │   ├── ets/
    │   │   ├── entryability/EntryAbility.ets
    │   │   ├── pages/             # Home、Item、Place、Activity、SharePreview 等
    │   │   ├── components/        # 统一面板、列表行、提示条、位置选择器
    │   │   ├── domain/            # 模型、校验、命令、查询、日期与待办计算
    │   │   ├── data/              # RDB、仓储、迁移、偏好、照片和备份
    │   │   ├── platform/          # 权限、AI、提醒、分享、系统入口适配
    │   │   └── extensions/        # 当前范围的卡片、互动卡片、编辑与备份扩展
    │   └── resources/
    │       ├── base/element/
    │       ├── dark/element/
    │       ├── base/media/
    │       └── base/profile/      # 当前范围的路由、卡片与备份配置
    ├── test/                      # 纯业务规则测试
    └── ohosTest/                  # 设备、扩展、恢复和 UI 场景
```

**Structure Decision**: 采用一个 `entry` 模块即可覆盖需求。先按同版本官方 Empty Ability Stage 模板创建工程，再按职责分目录，不引入额外服务端或无业务价值的模块。上述私有签名文件只表示配置隔离要求；实际方式以 DevEco 工具支持为准。

## 模块职责与调用顺序

1. 页面、卡片和外部入口先调用 `EntryRouter.resolve(request)`；外部写请求只生成候选，转交统一面板。
2. 用户确认后，面板调用 `CommandService.execute(command, operationId, expectedVersions)`；卡片 W6 只能构造白名单 `ConsumeOne`。
3. `WriteCoordinator` 串行调度；`CommandService.execute` 在 RDB 事务中重新读取、校验数量/版本、修改实体、写动态及回执并提交。
4. 提交后发布带数据版本的 `DomainChanged`，再更新查询视图、待办、卡片、提醒和索引。系统适配失败不回滚已完成的用户操作。
5. 用户点撤销时，调用 `UndoService.undo(receiptId)`，同样排队并在事务内校验，拒绝覆盖后续变动。
6. `QueryService` 统一生成物品、位置、待办和共享内容快照；核心问答直接展示查询结果与依据，不依赖模型。企业可选扩展未实施时不加载相关适配器，业务提交不等待这些渠道；选做后的查询、确认与模型约束见文末 US10。

队列不能仅靠页面内 Promise 链假定跨扩展全局串行。实施时核对扩展进程模型：优先让所有入口由同一写入宿主处理；若扩展须独立执行，则以数据库事务锁、预期版本及唯一 `operationId` 实现跨进程互斥和去重，并用并发设备测试证明 R14。不得通过持久后台进程保活实现。

## 阶段与完成条件

各阶段遵循 `capability-compatibility.md`：高版本接口在组件创建、初始化与调用前完成保护；按 SysCap、专用检测、授权、资源状态和用户偏好启用增强能力。不可用时保留输入并自动回到基础方案，不按芯片或机型划分整套能力。T015 定义共用检测，T104 接入 AI 降级，T122 接入视觉分级；分别验证可用、不支持、未就绪及恢复状态。

| 阶段 | 范围 | 完成条件 |
| --- | --- | --- |
| S0 工程与规范基线 | T001–T008 | 官方模板工程可复现，指定名称包名和图标正确接入，编译/最低版本分别锁定；不等待所有平台资格 |
| S1 共用基础 | T009–T017 | 模型、事务、撤销、日期、能力检测和通用 UI 可供故事使用 |
| S2 US1–US3 | 搜索记下、位置、数量 | T1、T2、T3、T9 及相关规则通过；形成可演示本机闭环 |
| S3 US4–US6 | 借还、待办、删除和备份 | T4–T7、T10，通过便携备份；调度按一次提醒、同日合并验收 |
| S4 US7 | 本地 AI、查询结果与非企业限定系统入口 | 支持设备按 T8、T12、T15 及 T13 查询结果部分验证；端 A2A 单独核验；不依赖 US10 |
| S5 US8 | 适配、素材动画和打磨 | 原设计目录、宽屏、大字号、图标、状态恢复通过 |
| S6 US9 | 原 P2 全部纳入 | 完成十条原 P2 需求及相应降级，按 QV-09 验证 |
| S7 完整交付核验 | US1–US9 全部非企业功能 | 119 条映射分别记录增强、降级、平台阻塞和未验证；65 条核心 P0 为底线，不能替代完整交付；US10 不参与当前验收 |

便携备份不等到所有系统集成完成后才设计：S1 确定格式，US6 完成实现，正式版之前必须通过。连续记下、购物和备份均先交付应用内完整流程；不要求实况窗。阶段顺序是执行建议；企业受限项的发布范围已按用户决定调整，原优先级仅用于追溯。

## 风险与控制

- 新建工程：选用 API 26 对应官方 Stage 模板，从零建立构建、模块、入口、资源和业务代码。
- `.gitignore` 当前忽略全部 `build-profile.json5`：后续跟踪公共构建配置，私有签名和本机路径单独忽略；不把密钥写入规格。
- 份合并、历史借还、撤销：保留来源与版本，在 `data-model.md` 规定合并后的引用调整与回执。
- 数据与照片的恢复提交：文件先落到新一代目录，事务切换引用；不在提交后才移动唯一照片副本。
- 提醒和卡片：同口径不等于后台同一时刻显示；按已发布数据版本对账。
- 官方系统备份和换机按需求正常接入；企业扩展未选做时不申请相关权益，不把资格材料作为核心前置条件，平台接入不得擅自增加应用服务端或网络权限。
- 最低版本选择先核对依赖与装载约束；增强能力缺失不提高全部业务的门槛。设备不足时保留未验证结果，不能把模拟权限拒绝当作真实低版本或硬件不支持测试。

## Complexity Tracking

无原则例外。新增本机命令去重记录和照片代际目录仅用于外部入口重复投递、跨扩展写入与恢复一致性，分别有业务触发场景和验证任务；不增加数据库、Redis 或其他基础设施故障处理系统。

## 最后阶段：US10 企业受限能力（可选，默认不执行）

对应 T148–T154，排在核心发布核验及后续 P2 任务之后。用户可选做单项，也可全部不做；不因顺序走到末尾就自动执行。选做前先核对当前官方规则、开发主体、设备和范围，满足后才申请、实现与验收。

- T148–T149：记录选做范围与资格，准备仅覆盖所选能力的 QV-10 验证。
- T150–T151：小艺意图 I1–I6、实体 E1、系统搜索和意图共享。外部写请求调用 EntryRouter.resolve(request) 生成候选，再由用户确认执行 CommandService.execute；不绕过隐私开关。
- T152：生成式端侧问答。QueryService 先产生事实，localChatModel 只组织语言，不能执行写命令；当前仅企业可申请且仅 PC/2in1，phone/tablet 不支持，指南还要求 INTERNET 权限。当前范围不能直接接入，扩设备或网络范围须有新的用户指令。
- T153：LV1–LV3 接入既有业务完成后的状态，核验正式权益、场景与锁屏样式，显式设置 AUTO_STOP_WHEN_APP_TERMINATE。推送路径明确要求企业账号；个人本地路径尚未核实可正式商用，整项按用户决定后置。不得为此新增远程 Push 服务端。
- T154：补齐所选扩展的配置、隐私、帮助及真实验收证据；未选项保持可选未实施。只有选做后的扩展发布需要其资格和 QV-10 通过。
