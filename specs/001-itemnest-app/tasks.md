# Tasks: 我的家当完整应用

**Input**: 本目录 spec、plan、research、data-model、contracts、platform-readiness。

**Status**: 仅为未来实施清单；本次全部未执行。取得新的开发指令后才开始。新项目工程从零创建；官方系统能力正常接入，提醒按一次提醒、同日合并实现。设备与平台条件按各任务核验。

**Tests**: 源需求明确要求 R1–R40 单测、设备验证、视觉和 T1–T15 走查，因此每个故事有针对性验证任务；不为文档本身创建应用测试。

## Format: `[ID] [P?] [Story] Description`

任务使用连续 T 编号。企业受限能力仅在文末 Phase 12 / US10，逐项标记“可选，默认不执行”，可全部不做；不纳入核心故事或首发必需项。无 `[P]` 标记的任务默认按依赖顺序进行；本套多处共享 schema、module 与资源文件，避免错误标记可并行。每个故事先建立必要测试/夹具，再实现，最后独立验收。

## Phase 1: Setup（工程与规范基线）

完成条件：按官方模板建立可复现最小工程，核对平台和素材；未授权时不执行。

- [ ] T001 核定 API 26 SDK、DevEco/Hvigor/ArkTS 配套版本、目标设备与签名方式，在 docs/engineering-baseline.md 记录实际工具路径和版本；落实 FR-015/FR-016。
- [ ] T002 按同版官方 Stage 模板补根 build-profile.json5、hvigorfile.ts、hvigor/hvigor-config.json5、oh-package.json5 和锁文件；模板若有 wrapper 则完整保留；修改 .gitignore 以跟踪公共构建配置并单独忽略私有签名/本机路径；落实 FR-015。
- [ ] T003 创建 entry/build-profile.json5、entry/hvigorfile.ts、entry/oh-package.json5、entry/src/main/module.json5 与 entry/src/main/ets/entryability/EntryAbility.ets；包名设置为 com.imotong.itemnest，应用名我的家当，声明 phone/tablet，建立默认产品/模块和首页；落实 FR-015。
- [ ] T004 补 entry/src/main/resources/base/profile/main_pages.json、base/element、dark/element、启动窗资源及 entry/src/test、entry/src/ohosTest 的官方测试入口；依赖版本使用配套模板且提交锁文件；落实 FR-015/FR-016。
- [ ] T005 使用官方 Image Asset 验收 AppScope/resources/base/media/ 的两份分层图标和三张 PNG；要求 1024×1024、背景完全不透明、无预裁圆角和不当内边距，核对桌面遮罩与启动窗；将素材来源、使用权和必要重导出记录写入 docs/asset-manifest.md；保留原素材源；落实 FR-016。
- [ ] T006 建立 docs/platform-config-manifest.md 并按实际已实现能力补 entry/src/main/module.json5 的 URI/share/NDEF skills、扩展、最小权限、材质元数据和对应 profile 资源；不先声明空扩展或 P2 权限，不申请网络权限；落实 FR-016。
- [ ] T007 在 docs/platform-entitlements.md 核对核心版本的代理提醒权益、签名与设备条件，以及 SYS-06 端 A2A 的具体主体/平台条件；记录证据，不能凭 SDK 声明认定已开通。代理提醒的现行指南未列企业主体限制，不一并后置；Intents、localChatModel、LV1–LV3 的资格、申请和集成全部留至可选 US10，不作为本任务完成条件。官方系统备份和换机正常接入；落实 FR-016。
- [ ] T008 在 docs/engineering-baseline.md 记录实际可用构建与 Hypium/设备测试命令、输出位置、安装及本机签名步骤；完成工程基线后构建并安装最小 HAP，只验证可启动和名称图标正确；落实 FR-015/FR-016。

## Phase 2: Foundational（共用基础）

完成条件：存储、事务、查询、回执、能力适配和通用 UI 可供后续故事使用；备份格式先按 contracts/backup.md 固定。

- [ ] T009 在 entry/src/main/ets/data/NestSchema.ets 定义 data-model.md 的 14 张业务表、command_log/reminder_delivery 及所需版本/历史字段；名称“1 至 80 字”、别名“每个 1 至 20 字，每件最多 10 个”、备注“物品 500 字；借出 200 字”、条码“256 字符”、分类/位置“1 至 40 字”、位置“最多 6 级，完整路径 200 字”、标签“40 字”、借用人“1 至 80 字”、数量“0 至 1,000,000，最多两位小数”、提前提醒“0 至 365”在校验与存储层一致；落实 DATA-01。
- [ ] T010 在 entry/src/main/ets/data/SchemaMigration.ets 实现 nest.db S3、版本从 1 开始逐级事务迁移；验证空位置/空日期的归一化唯一键、规范化同名键和历史引用约束；迁移测试置 entry/src/ohosTest/ets/test/SchemaMigration.test.ets；落实 DATA-01。
- [ ] T011 在 entry/src/main/ets/domain/WriteCoordinator.ets、CommandService.ets 建立排队事务与唯一 operationId；核对扩展进程模型，跨进程通过事务锁/版本/去重维护 R14，不以页面队列冒充全局队列；落实 DATA-01 与 R14。
- [ ] T012 在 entry/src/main/ets/domain/CommandReceipt.ets、UndoService.ets 定义前后值、版本、来源合并及连带归还范围，新增 loan_return.version，拒绝覆盖后续修改；设计五秒提示与历史纠正的不同可用期；落实 R12/R15/R16。
- [ ] T013 在 entry/src/main/ets/domain/Quantity.ets、LocalDate.ets、TodoCalculator.ets 定义百分之一整数、日期/时区、R20/R22/R23 的统一计算与确定性排序；加入边界夹具 entry/src/test/DomainFixtures.ets；落实 DATA-01。
- [ ] T014 在 entry/src/main/ets/data/PhotoStore.ets、CaptureDraftStore.ets、SettingsStore.ets 定义照片代际/暂存、被打断草稿、多会话与隐私偏好，保护有效文件不被清理；照片“每件 9 张”“单张原图导入后不超过 10 MiB”；落实 DATA-06/CAP-08。
- [ ] T015 在 entry/src/main/ets/platform/CapabilityService.ets、EntryRouter.ets 建立能力/授权/资格分别检查和外部确认路由，默认不接云端替代；落实 AI-10/SYS-01/R34。
- [ ] T016 在 entry/src/main/ets/domain/QueryService.ets、DomainChanged.ets 统一物品、位置、搜索、待办和共享快照，提交后用数据版本刷新投影，不在入口重复计算数量；落实 DATA-01/TODO-02。
- [ ] T017 在 entry/src/main/ets/components/OperationSheet.ets、AppShell.ets、MaterialStyle.ets 建立面板、通用底栏、深浅色资源接入和无障碍基础；先完成静态回退，具体动效随对应功能接入；落实 NAV-01/NAV-02/VIS-01/VIS-05。

## Phase 3: User Story 1 - 记下并找到东西（US1）

目标：完成 spec.md 的 US1；独立验收按 quickstart.md 的 QV-01，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T018 [US1] 在 entry/src/test/Story1.test.ets 与 entry/src/ohosTest/ets/test/Story1.test.ets 建立 QV-01 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T019 [US1] 在 entry/src/main/ets/components/AppShell.ets 实现 NAV-01「悬浮底栏」（P0，FR-001）：底栏是悬浮在内容上的玻璃底栏，五个位置依次为"物品、位置、＋、待办、我的"，应用启动后停在"物品"。＋不是栏目：点击在当前页面打开记下面板，长按弹出"语音、扫码、拍照、连续"四个快捷项；使用 `Tabs.barFloatingStyle`：三档宽度、材质 G1、开启左右手适配；键盘弹出时隐藏；在任一栏目点＋，记下面板在当前页面打开，所在栏目不变；动效 M02、M03、M04；待办位置显示角标（R23）。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T020 [US1] 在 entry/src/main/ets/components/OperationSheet.ets 实现 NAV-02「面板通则」（P0，FR-001）：记下、选位置、选分类，以及 STOCK、LEND、TODO 中的操作，都在当前页面的底部面板里完成，不推入新页面；面板关闭后，页面和滚动位置与打开前相同；返回键和下滑只关闭面板；面板内的二级视图（例如选位置）在同一面板内切换，不叠加第二层；面板使用材质 G3，动效 M14、M15。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T021 [US1] 在 entry/src/main/ets/components/UndoBar.ets 实现 NAV-03「提示条与撤销」（P0，FR-001）：能撤回的操作完成后，底栏上方显示提示条（`HdsSnackBar`）：结果文字、"撤销"，需要时加"查看"；显示 5 秒，读屏开启时 10 秒并可被读屏聚焦；新提示条替换旧的；撤销按 R16 核对，无法撤销时说明原因；动效 M16、M17；覆盖记下、补货、用掉、过期处理、移动、更正、借出、归还、资料编辑、删除、批量操作。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T022 [US1] 在 entry/src/main/ets/pages/Home.ets 实现 FIND-01「首页直接搜索」（P0，FR-003）："物品"栏目顶部是可以直接输入的搜索框，点击即弹出键盘，结果在列表区域实时显示，不切换栏目（T1）；清空后恢复浏览状态和原来的滚动位置；小艺"查找物品"、`itemnest://function/search`、桌面卡片的搜索条和 Ctrl+F 都聚焦这个搜索框。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T023 [US1] 在 entry/src/main/ets/domain/SearchService.ets 实现 FIND-02「匹配范围与多关键词」（P0，FR-003）：按 R32 匹配名称、别名、分类、位置路径、条码和备注；空格分开的多个关键词需要同时命中；搜"冰箱"能找到放在"厨房 › 冰箱 › 冷藏层"的所有物品；最近删除中的物品不出现。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T024 [US1] 在 entry/src/main/ets/domain/PinyinIndexer.ets 实现 FIND-03「拼音」（P1，FR-003）：名称、别名和位置支持拼音全拼和首字母，例如"cdq"和"chongdianqi"都能找到"充电器"（R32）。拼音在保存时生成。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T025 [US1] 在 entry/src/main/ets/components/SearchResultRow.ets 实现 FIND-04「排序与高亮」（P0，FR-003）：结果按 R32 分档排序，行内高亮命中的部分；分处存放的物品，第二行显示命中的那一处位置（动效 M07）。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T026 [US1] 在 entry/src/main/ets/components/SearchEmptyState.ets 实现 FIND-05「无结果」（P0，FR-003）：没有结果时显示"记下'关键词'"，点击打开预填名称的记下面板；有带照片的物品且外观搜索可用时，同时提供"按外观找"（AI-04）。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T027 [US1] 在 entry/src/main/ets/data/SearchHistoryStore.ets 实现 FIND-07「最近搜索」（P1，FR-003）：搜索框为空且获得焦点时显示最近搜索（R33），可以一键清空。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T028 [US1] 在 entry/src/main/ets/components/BrowseFilterBar.ets 实现 FIND-08「浏览筛选与排序」（P1，FR-003）：浏览状态提供筛选"全部、消耗品、借出中、有到期日、分类"，排序"最近动过、最近记下、名称、到期日"；选择自动记住。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T029 [US1] 在 entry/src/main/ets/components/AnswerCard.ets 实现 FIND-09「答案卡」（P1，FR-003）：唯一结果且名称完全相同时显示答案卡，突出封面与位置；普通物品操作为移动/借出，消耗品为用掉 1/补货。这是 S-11 的规划建议，若用户不同意先调整。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T030 [US1] 在 entry/src/main/ets/components/CaptureSheet.ets 实现 CAP-01「记下面板」（P0，FR-004）：记下面板打开即聚焦名称并弹出键盘。名称是唯一必填项；位置为空时保存为"未放位置"；输入名称、点一个最近位置、点"记下"，3 次点击完成（T2）；保存后回到原处，提示条显示"已记下'名称'"和"查看""撤销"（动效 M18）；名称为空时"记下"不可点；在名称框按回车等同点"记下"。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T031 [US1] 在 entry/src/main/ets/components/CapturePlaceField.ets 实现 CAP-02「位置默认值与候选」（P0，FR-004）：连续记下时继续选择上一件的位置；其他情况不预选，最近用过的位置排在候选第一个（R31）；候选显示最近用过的 5 个位置和"选择…"，后者在面板内打开位置选择器（PLACE-03）；在位置框输入时同时按名称和拼音搜索已建立位置；没有匹配时可以新建，并选择它的上级，默认顶层。用户不需要输入任何路径分隔符。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T032 [US1] 在 entry/src/main/ets/components/CaptureOptionalFields.ets 实现 CAP-03「选填项按需展开」（P0，FR-004）：照片、数量、到期、分类、备注、条码、别名排成一行，点哪项展开哪项。物品是消耗品时数量项默认展开；只填名称和位置时，面板上没有其他输入框；到期项下方显示"到期前 N 天提醒｜改"。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T033 [US1] 在 entry/src/main/ets/components/DuplicateItemHint.ets 实现 CAP-05「重名提示」（P0，FR-004）：输入的名称与已记录物品去掉空格后相同，或一方包含另一方时，在名称下方列出这些物品和位置（最多 3 件）。点"是这件"关闭面板，在那件物品上打开补货面板（消耗品）或移动面板（普通物品）。扫到已登记条码时同样处理。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T034 [US1] 在 entry/src/main/ets/components/ContinuousCapture.ets 实现 CAP-06「连续记下」（P0，FR-004）：面板顶部有"连续记下"开关。开启后每次记下只清空名称、照片、数量、到期日、备注、条码和别名，保留位置、分类、单位和消耗品开关，焦点回到名称；标题显示"本次已记 N 件"，点开可以查看，也可以删掉其中某一件（动效 M19）；从位置页"连续记下"打开时已开启此模式并预填该位置；每件只需输入名称再点一次（T9）；离开应用时保存录入进度与草稿；LV2 只在文末可选扩展选做后接入，不属于本任务完成条件。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T035 [US1] 在 entry/src/main/ets/domain/CaptureEntryResolver.ets 实现 CAP-07「统一入口与预填」（P0，FR-004）：底栏＋及长按快捷项、位置页、搜索无结果、系统分享、桌面卡片、已接入的端 A2A、`itemnest://function` 的 add、scan、camera、voice 都打开同一个记下面板，按 experience.md"入口与预填"表预填。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T036 [US1] 在 entry/src/main/ets/data/CaptureDraftStore.ets 实现 CAP-08「草稿」（P0，FR-004）：面板被下滑关闭、被外部入口打断或应用退到后台时，保存当前输入到偏好 `capture_draft`。再次打开记下面板时询问"继续记'名称'？"，选"放弃"才清除。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T037 [US1] 在 entry/src/main/ets/domain/CategoryRecommender.ets 实现 CAP-09「分类推荐」（P1，FR-004）：按名称推荐分类：先看同名物品用过的分类，再看内置关键词表（例如名称含"药""片""胶囊"推荐药品，含"纸""电池""洗衣"推荐生活用品）。推荐的分类显示为已选中的"推荐"，可以取消；消耗品开关随分类给出默认值（R19）。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T038 [US1] 在 entry/src/main/ets/data/RecentUnitStore.ets 实现 CAP-10「单位排序」（P1，FR-004）：单位列表把最近用过的 3 个单位放在最前面。 验收按 QV-01 及 docs/request.md 的同编号要求。
- [ ] T039 [US1] 在 entry/src/main/ets/components/ExpiryPicker.ets 实现 CAP-11「到期快捷项」（P1，FR-004）：到期日选择器旁提供"3 天后、1 周后、1 个月后、3 个月后、1 年后"。 验收按 QV-01 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-01 和本阶段逐条验收通过后才算 US1 完成；文档生成不算完成。

## Phase 4: User Story 2 - 位置与标签（US2）

目标：完成 spec.md 的 US2；独立验收按 quickstart.md 的 QV-02，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T040 [US2] 在 entry/src/test/Story2.test.ets 与 entry/src/ohosTest/ets/test/Story2.test.ets 建立 QV-02 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T041 [US2] 在 entry/src/main/ets/pages/Places.ets 实现 PLACE-01「位置栏目」（P0，FR-005）：列出顶层位置及其物品数、下级位置数，另有"未放位置"。顶部可以按名称、路径和拼音搜索位置；右上角是"扫标签"和"新位置"；物品数包含所有下级位置里的物品，不含最近删除中的物品。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T042 [US2] 在 entry/src/main/ets/pages/Place.ets 实现 PLACE-02「位置页」（P0，FR-005）：显示路径导航、下级位置、本位置的物品（默认包含下级，可以切换"只看这一层"），底部是"在这里记下"和"连续记下"；菜单包含标签、分享清单、改名、移到…、合并到…、删除（动效 M27）；扫标签、碰 NFC、打开 `itemnest://location/{token}` 都进入位置页（T8）。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T043 [US2] 在 entry/src/main/ets/components/PlacePicker.ets 实现 PLACE-03「位置选择器」（P0，FR-005）：记下、补货、移动、批量移动共用同一个位置选择视图：搜索、最近用过的 5 个、逐层浏览（路径导航返回）、"选当前这一级"、"在这里新建"；选中一个三级位置最多 4 次点击；在"最近"里时 1 次。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T044 [US2] 在 entry/src/main/ets/domain/PlaceService.ets 实现 PLACE-04「位置结构」（P0，FR-005）：位置可以多层，同一上级下名称不重复，改名和移动按 R28 处理；拖动可以调整同级顺序。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T045 [US2] 在 entry/src/main/ets/domain/PlaceMergeService.ets 实现 PLACE-05「删除与合并」（P1，FR-005）：按 R29 删除或合并位置。执行前说明影响，例如"12 件物品和 2 个下级位置将移到'卧室'，1 个标签将失效"，确认后执行。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T046 [US2] 在 entry/src/main/ets/components/RoomPicker.ets 实现 PLACE-06「常见房间」（P1，FR-005）：还没有位置时，位置栏目和首次使用引导提供常见房间多选，一键创建为顶层位置。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T047 [US2] 在 entry/src/main/ets/components/PlaceLabelSheet.ets 实现 PLACE-07「标签」（P1，FR-005）：位置页的标签面板中：生成二维码（预览、保存到图库、分享，图片含二维码、位置名、路径和"我的家当 · 扫一扫查看物品"）；写入 NFC（写前提示会覆盖标签原内容，动效 M30）；查看已绑定的标签并改名、解除；扫码或读取已绑定标签改绑到此位置（原属其他位置时先确认）。规则见 R30。 验收按 QV-02 及 docs/request.md 的同编号要求。
- [ ] T048 [US2] 在 entry/src/main/ets/components/InvalidLabelState.ets 实现 PLACE-08「失效标签」（P1，FR-005）：扫到没有关联位置的标签时，提示"这个标签没有关联位置"，并提供"绑定到…"打开位置选择器。 验收按 QV-02 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-02 和本阶段逐条验收通过后才算 US2 完成；文档生成不算完成。

## Phase 5: User Story 3 - 数量与撤销（US3）

目标：完成 spec.md 的 US3；独立验收按 quickstart.md 的 QV-03，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T049 [US3] 在 entry/src/test/Story3.test.ets 与 entry/src/ohosTest/ets/test/Story3.test.ets 建立 QV-03 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T050 [US3] 在 entry/src/main/ets/components/MultiSelectBar.ets 实现 NAV-04「多选与批量」（P1，FR-001）：物品列表、搜索结果、位置页支持多选，批量"移动到、设分类、分享、删除"；长按菜单和页面菜单都能进入多选；批量操作在一个事务里完成，提示条可以整体撤销。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T051 [US3] 在 entry/src/main/ets/pages/Item.ets 实现 ITEM-01「首屏内容」（P0，FR-006）：物品页标题是物品名称。在 360vp × 780vp 的竖屏窗口中，不滚动可以看到封面（抠图优先）、名称、状态标签（已过期、快到期、借出中、要补货）、位置、消耗品的在手数量和操作栏。进入动效 M11。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T052 [US3] 在 entry/src/main/ets/components/PortionList.ets 实现 ITEM-02「在手与份」（P0，FR-006）：只有一份时显示一行，例如"在手 6 盒 · 储物柜"；多份时逐行显示每份的位置、在手数量和到期日（R6）。点一行打开这一份的操作：移动、用掉、更正数量、改到期日；各行在手数量之和等于物品的在手数量；数量变化使用动效 M12、M13。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T053 [US3] 在 entry/src/main/ets/components/ItemActionBar.ets 实现 ITEM-03「操作栏」（P0，FR-006）：物品页底部是操作栏（`HdsActionBar`），内容随物品类型变化（R18）：；消耗品："用掉 1、补货、移动、更多"；"更多"含借出、更正数量、补货提醒、分享、复制为新物品、删除；普通物品："移动、借出、更多"；有借出未还时增加"归还"，全部借出时不显示"借出"；"更多"含更正数量、分享、复制为新物品、删除。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T054 [US3] 在 entry/src/main/ets/components/ItemFieldEditor.ets 实现 ITEM-04「就地编辑」（P0，FR-006）：名称、分类、备注、条码、别名、单位、提前提醒天数、消耗品开关在物品页上点击即编辑，单项保存；只写被改的字段，不回写数量、位置和到期日；每次保存可以撤销。没有独立的编辑页面；改单位时提示"记录数量不会换算"（R2）。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T055 [US3] 在 entry/src/main/ets/components/ConsumableSwitch.ets 实现 ITEM-07「消耗品开关」（P0，FR-006）：物品资料中有"消耗品"开关，新建时按 R19 取默认值，随时可以切换；切换只改变显示和可用操作（R18）。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T056 [US3] 在 entry/src/main/ets/pages/Activity.ets 实现 ITEM-08「动态与全部动态」（P0，FR-006）：物品页显示最近 5 条动态（R17），"全部"进入全部动态页。借出、归还可以在动态里纠正和撤销（LEND-03）；被撤销的动态标注"已撤销"。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T057 [US3] 在 entry/src/main/ets/domain/ConsumeService.ets 实现 STOCK-01「用掉」（P0，FR-007）：消耗品可以在物品页操作栏、列表长按菜单、待办、答案卡和桌面卡片 W6 上直接"用掉 1"：从最早到期、在手大于 0 的一份扣减，不离开当前页面（T3）。"用掉…"面板可以选数量（1、2、5、全部，或输入）和来源份；提示条显示"已用掉 1 盒，还剩 5 盒"；这次用掉让物品进入购物清单时，加"，已加入购物清单"；超过在手时主按钮不可点，并用一句话说明原因（R8），触感 H4；最早份不足 1 时按 DM-01 转用掉面板，不静默跨份或跳过。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T058 [US3] 在 entry/src/main/ets/components/RestockSheet.ets 实现 STOCK-02「补货」（P0，FR-007）：补货面板按 R21 预填数量和位置，提供"和上次一样"一键确认；到期日选填；保存时按 R4 合并或新建一份。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T059 [US3] 在 entry/src/main/ets/domain/MoveService.ets 实现 STOCK-03「移动」（P0，FR-007）：移动面板选择目标位置；有多份时先选移哪一份；移动后按 R4 合并。普通物品只有一份时，"移动"直接打开位置选择视图。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T060 [US3] 在 entry/src/main/ets/components/MoveQuantityField.ets 实现 STOCK-04「部分移动」（P1，FR-007）：移动面板可以填写移动数量，默认整份；少于整份时按 R15 拆分；从"储物柜 · 4 盒"移 2 盒到冰箱后，两处各显示 2 盒，到期日不变。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T061 [US3] 在 entry/src/main/ets/components/AdjustSheet.ets 实现 STOCK-05「更正数量」（P0，FR-007）：在某一份上更正数量，面板问"这里实际有几个"，按 R9 保存。物品有借出未还时，保存后借出数量不变，这一份的在手等于输入值。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T062 [US3] 在 entry/src/main/ets/domain/UndoService.ets 实现 STOCK-06「撤销」（P0，FR-007）：记下、补货、用掉、过期处理、移动、更正都返回回执，提示条上可以撤销（R16）。撤销前这件物品又有其他数量操作时，撤销被拒绝并说明原因。 验收按 QV-03 及 docs/request.md 的同编号要求。
- [ ] T063 [US3] 在 entry/src/main/ets/domain/DiscardService.ets 实现 STOCK-07「过期处理」（P0，FR-007）：已过期的消耗品可以"处理掉"：这一份的在手清零，动态记一条"过期处理"（`DISCARD`），提示条可以撤销（T7）。 验收按 QV-03 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-03 和本阶段逐条验收通过后才算 US3 完成；文档生成不算完成。

## Phase 6: User Story 4 - 借出与归还（US4）

目标：完成 spec.md 的 US4；独立验收按 quickstart.md 的 QV-04，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T064 [US4] 在 entry/src/test/Story4.test.ets 与 entry/src/ohosTest/ets/test/Story4.test.ets 建立 QV-04 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T065 [US4] 在 entry/src/main/ets/components/LendSheet.ets 实现 LEND-01「借出面板」（P0，FR-008）：借出面板包含借给谁（最近借用人候选和输入框，R13）、数量（消耗品或在手多于 1 件时显示，默认 1）、从哪一份（有多份时显示，R10）、约定归还（LEND-04）和备注；在物品页点"借出"、点一个借用人候选、点"确认"，3 次点击完成（T4）；完成后回到原处，提示条可撤销。 验收按 QV-04 及 docs/request.md 的同编号要求。
- [ ] T066 [US4] 在 entry/src/main/ets/components/ReturnSheet.ets 实现 LEND-02「归还」（P0，FR-008）：物品页、待办、借出未还分组里，每笔借出旁的"已归还"一次归还这一笔的全部未还数量，提示条可撤销（T5）；部分归还通过"归还…"面板选择数量。规则见 R11。 验收按 QV-04 及 docs/request.md 的同编号要求。
- [ ] T067 [US4] 在 entry/src/main/ets/domain/LoanCorrectionService.ets 实现 LEND-03「纠正与撤销」（P0，FR-008）：在动态中可以纠正借出或归还的借用人、数量、约定日期和备注，或撤销一笔记录（R12）。撤销直接执行，提示条上可以恢复，不先弹确认框。 验收按 QV-04 及 docs/request.md 的同编号要求。
- [ ] T068 [US4] 在 entry/src/main/ets/components/DueDatePicker.ets 实现 LEND-04「约定归还日期」（P1，FR-008）：借出面板提供"约定归还"：不确定、1 周后、1 个月后、选日期。过了约定日期仍未还的借出进入待办"该还了"并计入角标，在提醒中一并通知（R24）；约定日期可以修改。 验收按 QV-04 及 docs/request.md 的同编号要求。
- [ ] T069 [US4] 在 entry/src/main/ets/components/LoansByPerson.ets 实现 LEND-05「按人汇总与提醒对方」（P1，FR-008）：待办的"借出未还"按借用人分组，显示件数和最早借出时间，展开后列出每一笔。"提醒对方"打开分享预览，预填可修改的提醒文字（data.md"分享文本"）。 验收按 QV-04 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-04 和本阶段逐条验收通过后才算 US4 完成；文档生成不算完成。

## Phase 7: User Story 5 - 待办、提醒与购物（US5）

目标：完成 spec.md 的 US5；独立验收按 quickstart.md 的 QV-05，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T070 [US5] 在 entry/src/test/Story5.test.ets 与 entry/src/ohosTest/ets/test/Story5.test.ets 建立 QV-05 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T071 [US5] 在 entry/src/main/ets/components/ReminderState.ets 实现 ITEM-05「到期与提醒状态」（P0，FR-006）：有到期日时显示最早到期日、剩余天数和提醒状态。提醒状态只有三类：已安排（"11月13日 9:00 提醒"，到点后显示"已提醒"）；未开启（"提醒已关闭｜开启"）；发不出（一句原因和一个处理按钮）。调度中间状态不显示。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T072 [US5] 在 entry/src/main/ets/pages/Todo.ets 实现 TODO-01「待办栏目」（P0，FR-009）：待办按"已过期、快到期、该还了、要补货、借出未还"分组显示，口径见 R22。已过期按过期天数从多到少，快到期按到期日从近到远；分组标题在滚动时悬浮。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T073 [US5] 在 entry/src/main/ets/components/TodoBadge.ets 实现 TODO-02「角标与提示条」（P0，FR-009）：底栏待办角标按 R23 计数；有待办时"物品"栏目顶部显示提示条，按紧急程度最多列三组数量，点击进入待办。卡片、角标和提示条在同数据版本下数量一致；后台卡片按 research.md 的同版本同口径和系统调度限制验收，不承诺精确同时刷新。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T074 [US5] 在 entry/src/main/ets/components/TodoActionRow.ets 实现 TODO-03「一键处理」（P0，FR-009）：每条待办右侧是主要操作，左滑（`HdsListItem` 滑动操作）或长按出现其余操作，内容见 experience.md"待办"。完成后行收起，一组清空时播放 M25，全部完成时播放 M26；普通物品的到期操作按 R18 显示改日期或不再提醒，不能用掉。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T075 [US5] 在 entry/src/main/ets/components/ShoppingList.ets 实现 TODO-04「购物清单」（P0，FR-009）："要补货"组就是购物清单。每条的"已买到"打开补货面板，"和上次一样"一键完成（T6）；"不再提醒补货"把补货提醒改为"不提醒"。顶部"分享购物清单"先预览再分享（SYS-02）。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T076 [US5] 在 entry/src/main/ets/domain/ShoppingSessionService.ets 实现 TODO-05「购物模式」（P1，FR-009）：购物清单上的"去购物"开始购物模式：逐项勾选"已买到"，结束时一起补货，可以批量按"和上次一样"确认；应用内显示未买项目和进度，未确认时库存不增加。全部勾选或点"结束购物"后进入批量补货确认；LV3 锁屏展示和 T14 留至文末可选扩展，不属于本任务完成条件。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T077 [US5] 在 entry/src/main/ets/components/ReminderOptIn.ets 实现 TODO-06「首次询问」（P0，FR-009）：第一次保存带到期日的物品后，提示条询问"到期前提醒你？［提醒我］［不用］"（R25）。选"提醒我"时请求通知授权并开启到期提醒。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T078 [US5] 在 entry/src/main/ets/platform/ReminderAdapter.ets 实现 TODO-07「每日提醒」（P0，FR-009）：按 R24 用系统代理提醒对每个到期事件提醒一次，同日事项合并为一条通知，不在提前窗口内每天重复，内容见 harmonyos.md"提醒与通知"。点通知：单件打开物品页，多件打开待办；错误码 1700002 按权限/签名/配额分别诊断，限制滚动窗口并按事件去重。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T079 [US5] 在 entry/src/main/ets/components/ReminderUnavailableState.ets 实现 TODO-08「通知不可用时」（P0，FR-009）：通知未授权、代理提醒发布失败或平台不允许时，待办、角标、提示条和卡片照常显示全部事项；"我的 › 提醒"显示一句原因和处理方式。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T080 [US5] 在 entry/src/main/ets/components/ReminderTimePicker.ets 实现 TODO-09「提醒时刻」（P1，FR-009）："我的 › 提醒"可以设置每天提醒的时刻，默认 9:00；修改后重新对账提醒计划。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T081 [US5] 在 entry/src/main/ets/domain/SnoozeService.ets 实现 TODO-10「稍后」（P1，FR-009）：快到期的条目可以"稍后"，到期当天再提醒；推迟期间不出现在待办、角标和卡片中（R22）。 验收按 QV-05 及 docs/request.md 的同编号要求。
- [ ] T082 [US5] 在 entry/src/main/ets/components/ReminderSettings.ets 实现 SET-02「提醒设置」（P0，FR-013）：到期提醒开关、默认提前天数（0 至 365）、提醒时刻、通知授权状态和"去开启"；提醒发不出时显示原因（TODO-08）。开关打开时请求通知授权并对账提醒计划。 验收按 QV-05 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-05 和本阶段逐条验收通过后才算 US5 完成；文档生成不算完成。

## Phase 8: User Story 6 - 删除、隐私与备份（US6）

目标：完成 spec.md 的 US6；独立验收按 quickstart.md 的 QV-06，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T083 [US6] 在 entry/src/test/Story6.test.ets 与 entry/src/ohosTest/ets/test/Story6.test.ets 建立 QV-06 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T084 [US6] 在 entry/src/main/ets/data/NestDatabase.ets 实现 DATA-01「数据库与规则」（P0，FR-012）：按 data.md 建立数据库 `nest.db` 和全部表，实现规则 R1 至 R40；所有写操作在事务内完成并排队执行（R14）；进程在任意时刻被结束，已提交的数据完整，未提交的改动不留下半条记录；新增辅助表和字段按 data-model.md，禁止历史借还被份清理级联删除。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T085 [US6] 在 entry/src/main/ets/data/BackupService.ets 实现 DATA-02「便携备份与恢复」（P0，FR-012）："我的 › 数据"可以导出 `.itemnest` 备份包和从文件恢复，格式见 data.md"备份包"，流程见 R40；恢复前显示预览（物品、位置、照片数量和备份时间），确认后才覆盖；覆盖前自动保存安全备份，可以在"我的 › 数据"另存；超过 3 秒的操作显示应用内进度；LV1 留至文末可选扩展，不是备份成功的前置条件；申请短时任务，在系统允许的短时任务额度内尝试后台完成，时限结束按提交边界处理；文件损坏、格式不对、空间不足时不改动当前数据，并说明原因；按 contracts/backup.md 的显式表白名单、压缩包安全校验与照片代际提交边界执行。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T086 [US6] 在 entry/src/main/ets/data/AutoBackupService.ets 实现 DATA-03「自动备份」（P1，FR-012）：开启自动备份时，应用在前台且距上次超过 7 天时在后台生成备份包，保留最近 3 份；"我的 › 数据"显示上次自动备份的时间和占用空间，可以导出任意一份或从中恢复。连续失败 3 次后在"我的"中提示。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T087 [US6] 在 entry/src/main/ets/extensions/ItemNestBackupExtension.ets 实现 DATA-04「系统备份与换机」（P1，FR-012）：开启系统备份恢复，实现备份扩展：备份一致的数据库副本和照片目录；通过系统换机或系统备份恢复后，数据和照片完整，提醒重新安排（T11）。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T088 [US6] 在 entry/src/main/ets/data/DeletedItemStore.ets 实现 DATA-05「最近删除」（P0，FR-012）：删除物品按 R26 进入最近删除，提示条可以撤销（T10）；"我的 › 数据 › 最近删除"列出这些物品，可以恢复或永久删除；30 天后自动永久删除（R27）。物品有借出未还时，删除前确认一次。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T089 [US6] 在 entry/src/main/ets/data/PhotoStore.ets 实现 DATA-06「照片存储」（P0，FR-012）：照片按 R37 导入和处理，存放在应用沙箱；按 R38 清理孤儿文件；删除或更换照片时同步更新以文搜图索引。 验收按 QV-06 及 docs/request.md 的同编号要求。
- [ ] T090 [US6] 在 entry/src/main/ets/pages/SystemPrivacy.ets 实现 SET-04「系统能力与隐私」（P0，FR-013）：实现照片外观搜索、本地问问家当、自动备份及已接入端 A2A 等已实现功能的开关，按 R39 生效；显示各项已选 AI 能力在本机是否可用（AI-10）。未选企业扩展不提供可启用开关、引导或共享行为；相关偏好可保留供未来兼容，但值不能绕过未实施状态。意图、系统搜索、意图共享、模型生成和 LV1–LV3 的开关与清理验收随 US10 对应任务完成。验收按 QV-06 及本次范围调整。

**Checkpoint**：QV-06 和本阶段逐条验收通过后才算 US6 完成；文档生成不算完成。

## Phase 9: User Story 7 - AI 与系统入口（US7）

目标：完成 spec.md 的 US7；按 QV-07 验收本地识别、语音、查询结果、卡片、分享及已选端 A2A。SYS-04、SYS-05、AI-09 模型生成和 SYS-08 只在末尾 US10 实施与验收，不是本故事依赖。

- [ ] T091 [US7] 在 entry/src/test/Story7.test.ets 与 entry/src/ohosTest/ets/test/Story7.test.ets 建立 QV-07 的规则、边界和适用设备验证；覆盖本故事已选能力及企业扩展全部缺席时的录入、查询、卡片与分享完整性，不要求实现 US10 的平台能力。
- [ ] T092 [US7] 在 entry/src/main/ets/platform/ScanAdapter.ets 实现 FIND-06「扫码查找」（P1，FR-003）：搜索框右侧的扫码按钮：条码属于一件物品时打开物品页，属于多件时列出这几件；扫到本应用的位置标签时打开位置页；都不是时提供"记下这个条码"。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T093 [US7] 在 entry/src/main/ets/components/RecognitionCandidates.ets 实现 CAP-04「照片识别候选」（P0，FR-004）：拍照或选图后自动识别包装文字（AI-01），名称和到期日候选以标签出现在对应输入项下方，点一下才填入（R35）；照片里有条码时同时给出条码候选；拍照、点名称候选、点到期候选、点"记下"，4 次点击完成；候选不覆盖用户已经输入的内容；识别失败时面板照常可用，只在照片下方说明一次。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T094 [US7] 在 entry/src/main/ets/platform/ContinuousScanAdapter.ets 实现 CAP-12「连续扫码记下」（P1，FR-004）：长按＋选"扫码"进入扫码记下；设备支持自定义扫码界面时可以连续扫描，每扫到一个码就加一条待确认物品（动效 M29），扫完一起进入记下面板逐件补名称和位置。条码已存在时提示补货（CAP-05）。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T095 [US7] 在 entry/src/main/ets/components/PhotoCollection.ets 实现 CAP-13「多张照片」（P1，FR-004）：每件物品最多 9 张照片（R37），第一张是封面；记下面板和物品页都能添加、排序、删除。照片可以来自拍照、相册、系统分享或扫描说明书（AI-06）。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T096 [US7] 在 entry/src/main/ets/components/PhotoViewer.ets 实现 ITEM-06「照片与大图」（P0，FR-006）：点封面打开大图浏览（材质 G4），左右滑动切换照片；大图中可以设为封面、更换、删除；支持图像分析时可以长按提取文字或主体（AI-05）。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T097 [US7] 在 entry/src/main/ets/platform/VisionAdapter.ets 实现 AI-01「包装文字识别」（P0，FR-010）：照片中的文字用 Core Vision Kit 文字识别，应用从中找出名称、生产日期、保质期和到期日，生成候选（CAP-04）。由生产日期和保质期推算的到期日标明"推算"；识别中播放 M21。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T098 [US7] 在 entry/src/main/ets/platform/SegmentationAdapter.ets 实现 AI-02「抠图封面」（P1，FR-010）：照片加入后用主体分割生成透明背景的抠图，作为物品封面显示在列表、物品页、答案卡和桌面卡片上（M20）。分割失败或设备不支持时用原图缩略图。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T099 [US7] 在 entry/src/main/ets/components/MultiObjectCapture.ets 实现 AI-03「一拍多件」（P1，FR-010）：长按＋选"拍照"后可以切到"一拍多件"：拍一张抽屉或箱子的照片，物体检测框出多件物品，用户点选要记下的框（M22），每个框的裁剪图成为一件物品的照片，然后在记下面板里逐件输入名称（T15）。位置统一预填。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T100 [US7] 在 entry/src/main/ets/platform/PhotoSearchAdapter.ets 实现 AI-04「按外观找」（P1，FR-010）：开启照片外观搜索时，照片保存后加入以文搜图索引（R37）。搜索无结果或用户点"按外观找"时，用描述（例如"红色盒子"）检索照片，结果标注"外观相似"，与名称结果分开显示。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T101 [US7] 在 entry/src/main/ets/platform/DocumentScanAdapter.ets 实现 AI-06「扫描说明书」（P1，FR-010）：物品页和记下面板的照片区提供"扫描说明书"，用文档扫描控件拍摄并矫正，保存为扫描件照片（`DOCUMENT`）。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T102 [US7] 在 entry/src/main/ets/platform/SpeechAdapter.ets 实现 AI-07「语音记下与语音操作」（P1，FR-010）：长按＋选"语音"、搜索框的麦克风、记下面板的麦克风都可以说话（端侧中文识别，使用时申请麦克风权限，动效 M23）：；记下："充电器放书房抽屉""两盒牛奶放冰箱，下周五到期"，解析为名称、数量、位置、到期日，预填记下面板（T12）；查找："护照在哪"，进入搜索并显示结果；操作："用掉一包纸巾""电钻借给小王""小王把电钻还了"，打开对应物品上预填的面板；解析方式见 harmonyos.md"本地 AI"；位置按名称和拼音匹配已建立位置，匹配不到时作为新位置候选。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T103 [US7] 在 entry/src/main/ets/domain/LocalQuestionService.ets 与 entry/src/main/ets/components/AnswerCard.ets 实现 AI-09「问问家当」的本地查询结果部分（原 P1，FR-010）：识别搜索框输入或语音中的位置、余量、到期、借出及位置清单问题，调用 QueryService 查询物品、数量、位置、日期，直接显示结果卡片与依据（R36、T13 查询部分）。多物品、多位置有歧义时展示候选；不导入 localChatModel，不播放生成流光或 M24，不显示模型准备提示。模型生成在 T152 可选实施；SYS-06 入口仅在其独立资格核验并接入后展示。验收按 QV-07。
- [ ] T104 [US7] 在 entry/src/main/ets/platform/CapabilityService.ets 实现 AI-10「可用性检测与降级」（P0，FR-010）：每项 AI 能力在使用前检查设备支持，不支持时隐藏对应入口，不报错；"我的 › 系统能力与隐私"列出各项 AI 能力在本机是否可用。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T105 [US7] 在 entry/src/main/ets/platform/EntryRouter.ets 实现 SYS-01「链接」（P0，FR-011）：按 data.md"链接"处理 `itemnest://item`、`location`、`function`。来自链接、NFC、通知的改动请求按 R34 先打开预填面板。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T106 [US7] 在 entry/src/main/ets/pages/SharePreview.ets 实现 SYS-02「分享预览」（P0，FR-011）：分享物品、位置清单、借出清单（按人）、购物清单、提醒对方的文字时，先在分享预览里确认内容和可选项（位置、备注、借用人、照片），再调起系统分享。格式见 data.md"分享文本"；物品分享生成带抠图封面的图片卡片。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T107 [US7] 在 entry/src/main/ets/platform/ShareAdapter.ets 实现 SYS-03「碰一碰分享」（P1，FR-011）：分享预览、物品页、位置页、购物清单打开时，与另一台设备碰一碰，即把当前内容（图片卡片和文字）分享过去（`harmonyShare`）；碰一碰同样遵守分享预览选项，不直接发送未确认隐私字段。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T108 [US7] 在 entry/src/main/ets/platform/AgentAdapter.ets 实现 SYS-06「智能体」（P1，FR-011）：先按 T007 核对个人账号具体可用的端 A2A/FunctionComponent 入口和当前官方接入方式，不沿用 Intents Kit 企业资格作为判断。满足条件后在小艺开放平台创建并关联应用，提供查询、待确认改动和待办摘要；确认后共用 CommandService；答案卡提供“在小艺里继续问”。资格不明、未获准或设备不支持时不显示可操作入口，记录核验结果及是否延期；不自动引入云服务、不作为本地问答前置条件。验收按 QV-07 及 SYS-06。
- [ ] T109 [US7] 在 entry/src/main/ets/extensions/ItemNestFormExtension.ets 实现 SYS-07「桌面卡片」（P0，FR-011）：实现 harmonyos.md 的六种卡片 W1 至 W6；W1 至 W3 为 P0，W4 至 W6 为 P1；卡片数据与待办同一口径，数据变化后主动刷新，每天 00:01 申请定点刷新，跨天获得运行机会时对账；支持浅色、深色和单色主题模式；W6 的"用掉 1"直接记一笔，卡片上 5 秒内可撤销（R34 例外），播放越界动效 M32；W4 至 W6 提供卡片编辑页，选择位置、物品或消耗品；后台卡片按 research.md 的同版本同口径和系统调度限制验收，不承诺精确同时刷新。 验收按 QV-07 及 docs/request.md 的同编号要求。
- [ ] T110 [US7] 在 entry/src/main/ets/platform/IncomingShareAdapter.ets 实现 SYS-09「接收分享」（P0，FR-011）：从系统分享收到的一张图片或一段文字，打开预填的记下面板；正在记下时先保存当前草稿再切换（CAP-08）。 验收按 QV-07 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-07 中本阶段已选能力和核心回退通过后才算 US7 完成；US10 不参与本检查点，未选 P1 明确记录延期；文档生成不算完成。

## Phase 10: User Story 8 - 原生体验、设置与多设备适配（US8）

目标：完成 spec.md 的 US8；独立验收按 quickstart.md 的 QV-08，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T111 [US8] 在 entry/src/test/Story8.test.ets 与 entry/src/ohosTest/ets/test/Story8.test.ets 建立 QV-08 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T112 [US8] 在 entry/src/main/ets/components/WideLayout.ets 实现 NAV-05「宽屏布局与拖放」（P1，FR-001）：平板和展开的折叠屏上，物品栏目显示"列表｜物品页"两栏，位置栏目显示"位置树｜位置页"两栏，侧栏使用 `HdsSideBar`；在列表里点另一件物品，右栏切换，左栏的滚动位置和筛选不变；可以把物品拖到左侧位置树的某个位置上完成移动（动效 M28），提示条可撤销。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T113 [US8] 在 entry/src/main/ets/pages/Onboarding.ets 实现 NAV-06「首次使用」（P1，FR-001）：首次启动依次显示欢迎、选房间、记下第一件三屏，每屏可以跳过，内容见 experience.md"首次使用"；欢迎屏提供"从备份恢复"；引导期间不请求任何权限。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T114 [US8] 在 entry/src/main/ets/platform/NavigationStateAdapter.ets 实现 NAV-07「状态保存与恢复」（P1，FR-001）：应用在后台被系统回收后再打开，回到原来的栏目、页面、滚动位置和未保存的输入（用 `NavDestination.onSaveState`、`onRestoreState`；记下面板另有草稿，见 CAP-08）。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T115 [US8] 在 entry/src/main/ets/platform/KeyboardAdapter.ets 实现 NAV-08「键盘快捷键」（P1，FR-001）：连接键盘时：Ctrl+F 聚焦搜索框，Ctrl+N 打开记下面板，Esc 关闭面板，Ctrl+Z 撤销最近一次操作（提示条还在时）。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T116 [US8] 在 entry/src/main/ets/components/UsageHint.ets 实现 NAV-09「一次性提示」（P1，FR-001）：长按菜单、连续记下、下拉唤起这类不显眼的操作，在用户第一次用得上时提示一次（例如列表里有 3 件以上物品时提示"长按物品，可以直接用掉、移动或借出"），点"知道了"后不再出现。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T117 [US8] 在 entry/src/main/ets/components/MaterialStyle.ets 实现 VIS-01「系统材质」（P0，FR-002）：底栏、标题栏、搜索框、面板、菜单、弹窗、提示条、＋按钮按 design.md 的 G1 至 G5 使用系统沉浸材质；在 `module.json5` 声明应用级材质开启；标题栏滚动时渐进模糊（M05）；玻璃层上的文字对比度不低于 4.5:1。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T118 [US8] 在 entry/src/main/ets/components/LightEffects.ets 实现 VIS-02「光效」（P1，FR-002）：卡片、按钮、列表行按 design.md 的 P1 至 P3 使用点光源和按压光影；识别和语音使用 P4 流光；模型生成流光仅随 T152 可选接入；"物品"栏目顶部有 P5 背景光晕；扫码使用 P6 扫光；持续光效同时只运行一个，页面不可见时停止。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T119 [US8] 在 entry/src/main/ets/components/MotionCatalog.ets 实现 VIS-03「动效」（P0，FR-002）：实现 design.md 中已选功能对应的 M01 至 M33，弹簧参数用 S1 至 S5；M24 的生成式问答效果只随 T152 可选接入，未选功能不要求空动效；M01 至 M20、M25、M27 随首个里程碑实现，其余随对应功能实现；动效可以被新操作打断；有手势的动效全程跟手。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T120 [US8] 在 entry/src/main/ets/platform/HapticAdapter.ets 实现 VIS-04「触感」（P1，FR-002）：按 design.md 的 H1 至 H7 在对应时刻触发系统振动预设，跟随系统触感开关。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T121 [US8] 在 entry/src/main/ets/platform/AccessibilityAdapter.ets 实现 VIS-05「减少动画与无障碍」（P0，FR-002）：系统"减少动画"开启时，按动效目录"减少动画时"一列表现；读屏、大字号、状态表达按 design.md"无障碍"一节；所有可操作元素有读屏文字；触控区域不小于 44vp × 44vp。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T122 [US8] 在 entry/src/main/ets/platform/CapabilityService.ets 实现 VIS-06「设备分级」（P0，FR-002）：按 `uiMaterial.getGlobalMaterialLevel()` 和 `isImmersiveMaterialSupported()` 区分精致、柔和、流畅三档，按 design.md"设备分级"开关效果。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T123 [US8] 在 entry/src/main/ets/components/CharacterView.ets 实现 VIS-07「形象动画」（P1，FR-002）：两位整理小伙伴的动画用于启动（M01）、引导、空状态、AI 思考中、全部完成（M26），随用户选择的形象切换；素材制作、动画源文件和许可记录纳入 docs/asset-manifest.md，每段不超过 3 秒并有静态回退。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T124 [US8] 在 entry/src/main/resources/base/element/color.json 实现 VIS-08「颜色与深浅色」（P0，FR-002）：所有颜色使用 design.md 的令牌，浅色、深色两套；主题可以跟随系统或手动选择（SET-05）。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T125 [US8] 在 entry/src/main/ets/pages/Me.ets 实现 SET-01「"我的"页面」（P0，FR-013）："我的"分为提醒、数据、整理、系统入口、外观、关于六组，结构见 experience.md"我的"。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T126 [US8] 在 entry/src/main/ets/pages/CategoryManager.ets 实现 SET-03「分类管理」（P0，FR-013）：分类可以新增、改名（同步到已记录物品）、停用和启用、调整顺序、设置"新物品默认是消耗品"。预设分类可以改名和停用，不能删除。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T127 [US8] 在 entry/src/main/ets/platform/AppearanceAdapter.ets 实现 SET-05「外观」（P0，FR-013）：主题（跟随系统、浅色、深色）立即生效；应用图标在两种形象间切换（`bundleManager.setAlternateIcon`），切换后以系统实际使用的图标确认结果，设备不支持时说明原因。启动和空状态的形象随之切换（VIS-07）。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T128 [US8] 在 entry/src/main/ets/components/AboutSheet.ets 实现 SET-06「关于与帮助」（P1，FR-013）：使用技巧（仅介绍已实现的长按、连续记下、语音、标签、卡片等功能，配动图；实况窗等企业扩展未选做时不展示相关引导）、数据与隐私说明（应用核心数据在本机、AI 在端侧运行、华为官方系统备份与换机、各开关的作用）、版本号。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T129 [US8] 在 entry/src/main/resources/base/element/string.json 实现 TEXT-01「术语」（P0，FR-014）：界面文字使用 product.md 的术语表：同一个概念全应用只用一个说法，不出现数据表名、字段名、英文枚举值。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T130 [US8] 在 entry/src/main/ets/components/ResultMessage.ets 实现 TEXT-02「说明与状态文字」（P0，FR-014）：界面不解释内部规则。只在操作被拒绝或结果出乎意料时，用一句话说明原因和下一步；状态文字只写用户看得懂、能处理的状态；出错时，用户能处理的原因要说出来（存储空间不足、通知被关闭），其余只说没成功并给出重试。物品页、记下面板和操作面板里，常驻的说明文字每处不超过一行。 验收按 QV-08 及 docs/request.md 的同编号要求。
- [ ] T131 [US8] 在 entry/src/main/ets/domain/DisplayFormatter.ets 实现 TEXT-03「日期与数字」（P1，FR-014）：日期 7 天内显示"今天、明天、3 天后、过期 2 天"，更远显示"11月20日"，不在今年时加年份。数量去掉末尾多余的 0（1.50 显示为 1.5）；数字和单位之间留一个空格，例如"2 盒"。 验收按 QV-08 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-08 和本阶段逐条验收通过后才算 US8 完成；文档生成不算完成。

## Phase 11: User Story 9 - 后续版本 P2（US9）

目标：完成 spec.md 的 US9；独立验收按 quickstart.md 的 QV-09，使用预置数据即可验证，不要求其他故事的全部界面先完成。

- [ ] T132 [US9] 在 entry/src/test/Story9.test.ets 与 entry/src/ohosTest/ets/test/Story9.test.ets 建立 QV-09 的规则、边界和适用设备验证；先覆盖本故事需求与 data-model.md 规则，再实现并记录实际结果。
- [ ] T133 [US9] 在 entry/src/main/ets/components/PullSearchGesture.ets 实现 FIND-10「下拉唤起」（P2，FR-003）：在"物品"栏目顶部下拉进入搜索，继续下拉松手开始语音查找（动效 M33）。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T134 [US9] 在 entry/src/main/ets/components/PlacePhoto.ets 实现 PLACE-09「位置照片」（P2，FR-005）：位置可以有一张照片，显示在位置页顶部和位置卡片上，帮助辨认柜子和箱子。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T135 [US9] 在 entry/src/main/ets/domain/CopyItemService.ets 实现 ITEM-09「复制为新物品」（P2，FR-006）："更多"中的"复制为新物品"打开记下面板，预填分类、单位、位置和消耗品开关。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T136 [US9] 在 entry/src/main/ets/pages/PersonManager.ets 实现 LEND-06「借用人管理」（P2，FR-008）：在借出未还分组的借用人菜单里可以改名，或合并两个借用人（例如"小王"和"王小明"）。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T137 [US9] 在 entry/src/main/ets/platform/ContactAdapter.ets 实现 LEND-07「从联系人选择」（P2，FR-008）：借给谁可以通过系统联系人选择器选择，只保存姓名和联系人标识。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T138 [US9] 在 entry/src/main/ets/platform/CalendarAdapter.ets 实现 LEND-08「写入日历」（P2，FR-008）：设置约定归还日期时，可以选择同时在系统日历中添加一条"收回电钻"的日程。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T139 [US9] 在 entry/src/main/ets/platform/NotificationActionAdapter.ets 实现 TODO-11「通知上的操作」（P2，FR-009）：每日提醒通知提供"查看"和"明天再提醒"两个按钮。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T140 [US9] 在 entry/src/main/ets/platform/ImageAnalyzerAdapter.ets 实现 AI-05「大图分析」（P2，FR-010）：物品大图支持图像分析：长按可以选取图中文字（如序列号）或抠出主体。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T141 [US9] 在 entry/src/main/ets/platform/TextToSpeechAdapter.ets 实现 AI-08「朗读回答」（P2，FR-010）：问问家当的回答卡上有朗读按钮，用系统朗读能力读出回答。 验收按 QV-09 及 docs/request.md 的同编号要求。
- [ ] T142 [US9] 在 entry/src/main/ets/platform/ContinuationAdapter.ets 实现 SYS-10「跨设备」（P2，FR-011）：平板上记下物品时可以用附近手机的相机拍照；手机上记到一半的物品或打开的物品页可以在平板上继续（应用接续）。 验收按 QV-09 及 docs/request.md 的同编号要求。

**Checkpoint**：QV-09 和本阶段逐条验收通过后才算 US9 完成；文档生成不算完成。

## 核心发布阶段：发布前交叉核验

US9 为后续范围，文末 US10 为可选企业扩展，两者均不阻塞首发。本阶段依赖排除 SYS-04 后的 65 条核心 P0 和选定非企业扩展 P1；不能因可选未实施而判定发布失败。

- [ ] T143 在 entry/src/ohosTest/ets/test/CrossEntryConcurrency.test.ets 验证页面/W6 并发、重复 operationId、跨扩展回执和后台回收，确认 R14/R16/R34 不被绕过；落实 DATA-01/SYS-07。
- [ ] T144 在 docs/acceptance-results.md 为 requirements-map.md 的 119 条原需求、R1–R40、T1–T15、设计目录和平台矩阵逐条记录实际结果。SYS-04、SYS-05、SYS-08 和 AI-09 模型生成部分分别记为可选未实施或选做后的真实结果；T13 拆查询与生成，T14 留 US10；其他未运行项保持未验证，P2 与延期 P1 分列，不把范围排除写成测试通过；落实 FR-001–FR-016/SC-001–SC-008。
- [ ] T145 在 docs/asset-manifest.md、docs/platform-config-manifest.md 核对核心版已实现功能的图标、启动窗、形象动画、资源引用、权限理由、资格和签名包 UX 结果，发布前替换 AppScope/app.json5 的 vendor 模板值；未选企业扩展不声明空扩展、不要求其资格或引导素材；落实 FR-016。
- [ ] T146 在 docs/performance-samples.md 记录典型小/中/大本机样本下启动、搜索、列表、照片和备份的真机数据；发现体验问题后定位优化，不将无证据的数值写成已通过指标；落实 SC-001/SC-003/SC-008。
- [ ] T147 在 docs/release-checklist.md 核对 65 条核心 P0、选定非企业扩展 P1、一次提醒同日合并、按选定范围完成的官方系统备份与换机、离线与隐私、备份安全和工程复现。SYS-04 原 P0 按用户决定转为 US10 可选，连同其他未选企业扩展记录“可选未实施”，不阻塞核心发布；其他必需平台能力仍须解决。更新 SpecKit 状态，不自动提交/推送/发布；落实 SC-007/FR-015/FR-016。

## Dependencies & Execution Order

- Setup T001–T008 → Foundational T009–T017 → US1–US8 → 核心发布核验；US9 单独选择。文末 US10 在上述任务之后且默认不执行，不作为任何核心任务的前置条件。
- 基础阶段包含数据结构和共享查询，因此 US2–US8 可用预置数据独立验证；完整用户流程仍要最后串联。
- US2 标签需要 SYS-01/Scan/NFC 适配；可先实现相应适配再做页面，不因 UI 故事排序误用未实现能力。
- US3–US7 共用数量服务；US4 借还事实供 US5 借出待办；US6 备份必须覆盖全部已定义业务表和照片。
- US1–US7 的应用内与外部入口共用命令和查询；官方系统能力按需求接入，提醒调度按一次提醒、同日合并实现；平台资格与运行授权按任务核验。
- US8 的基础材质/无障碍由 T017 起持续接入；新增组件必须一起满足深浅色和可访问性，不能等最后才补。
- 同一故事内按“测试/模型 → 业务服务 → 界面/适配 → 独立验收”排序；上面的编号是执行跟踪顺序，遇到明确依赖先完成依赖，不能用替身实现冒充真实能力。

## Parallel Opportunities

每个故事的纯规则测试设计可与其 UI 草图/资源核对同时准备；US1 搜索与记下、US2 树与标签、US3 数量校验与面板、US4 纠正规则与面板、US5 计算与展示、US6 格式校验与恢复页面、US7 各独立 Kit 研究、US8 形象素材与宽屏布局、US9 各选定后续项可在依赖齐备后分别推进。共享 schema/module/资源、写协调器和最终集成按顺序修改，因此未给具体任务加 `[P]`。

## Implementation Strategy

先完成 US1 手工记下与查找，联合 US2/US3 形成可演示本机闭环；再补借还、待办和便携备份。系统能力和外观按本次范围收敛，65 条核心 P0 和选定非企业扩展 P1 验收后构成核心正式版；企业可选项不阻塞。实施时完成一项才勾选一项；本次只交付计划，所有任务保持未勾选。

任务总数：154；Setup 8、Foundational 9、各故事 US1 22、US2 9、US3 15、US4 6、US5 13、US6 8、US7 20、US8 21、US9 11、核心发布核验 5、文末 US10 可选扩展 7。前 147 项仍含选定 P1 与后续 P2，不等于 147 项全部首发必做。

## Phase 12: User Story 10 - 企业受限能力扩展（US10，可选，默认不执行）

本阶段排在核心发布核验及后续 P2 任务之后，允许全部不做。只有用户后续明确选择具体能力，并且具备所需主体、设备和平台条件时才执行；没有选做的条目保持未勾选，记录为“可选未实施”，不阻塞核心版本发布。不能因运行到任务清单末尾而自动开始。

目标：保留 SYS-04、SYS-05、AI-09 的模型生成部分、SYS-08 的完整需求；原输入优先级仅用于追溯。独立验收使用 QV-10，各能力可分别选择，不要求整组接入。

- [ ] T148 [US10] 【可选，默认不执行】在 docs/enterprise-capabilities.md 记录本次选做范围、用户选择和逐项资格：Intents Kit 的企业主体要求；localChatModel 的企业申请、仅 PC/2in1 支持及 INTERNET 权限与当前范围的冲突；Live View Kit 推送路径的企业要求、本地路径的正式权益和 LV1–LV3 场景准入。条件不符停止对应扩展，不扩展到 PC、不引入网络或服务端；需要改变这些范围时先取得新的用户指令。不得将代理提醒或独立端 A2A 自动归为企业专属。
- [ ] T149 [US10] 【可选，默认不执行】在 entry/src/test/Story10.test.ets 与 entry/src/ohosTest/ets/test/Story10.test.ets 建立 QV-10 中本次选做能力的验证：意图/实体与隐私开关、模型依据校验、LV1–LV3 场景和生命周期；未选能力不要求实现或提交平台。US1–US8 已覆盖扩展缺席时的完整核心流程。
- [ ] T150 [US10] 【可选，默认不执行】在 entry/src/main/ets/platform/IntentAdapter.ets 实现 SYS-04「小艺意图与系统搜索」（原 P0，现为可选扩展，FR-011）：实现 harmonyos.md 的意图 I1 至 I5 和物品实体 E1；I6（在小艺里显示待办卡片）原为 P1，本次同为可选扩展；查询类意图返回以位置开头的回答；记录类意图打开预填面板，回答"已准备好，请在应用里确认"；"允许小艺查询与操作""允许系统搜索物品""系统搜索结果显示位置"三个开关按 R39 生效。 验收按 QV-10 及 docs/request.md 的同编号要求。
- [ ] T151 [US10] 【可选，默认不执行】在 entry/src/main/ets/platform/IntentSharingAdapter.ets 实现 SYS-05「意图共享」（原 P1，现为可选扩展，FR-011）：用户执行查找、看待办、用掉、打开购物清单后，把这次操作分享给系统，用于小艺建议；物品删除时删除相关实体；开关关闭时删除全部已分享的意图。 验收按 QV-10 及 docs/request.md 的同编号要求。
- [ ] T152 [US10] 【可选，默认不执行】在 entry/src/main/ets/platform/LocalQaAdapter.ets 与 entry/src/main/ets/components/AnswerCard.ets 实现 AI-09 的模型生成部分（原 P1，现为可选扩展，FR-010）：仅在 T148 的范围和资格核定完成后接入 localChatModel；先由 QueryService 查询物品、在手/共有、位置、日期和借还事实，模型只组织一句话并流式展示（M24），下方保留依据。生成内容不符事实时丢弃，未就绪或开关关闭时返回 T103 的查询结果卡片，不调用云端替代。按 QV-10 验收 R36 和 T13 的生成式部分；取得企业账号也不等于当前手机/平板已支持该模型。
- [ ] T153 [US10] 【可选，默认不执行】在 entry/src/main/ets/platform/LiveViewAdapter.ets 实现 SYS-08「实况窗」（原 P1，现为可选扩展，FR-011）：实现 harmonyos.md 的三种实况窗：LV1 备份与恢复、LV2 连续记下、LV3 购物清单（自定义展开区和锁屏样式）；用户关闭对应开关、系统不允许或平台未开通时不创建，应用内照常显示进度；LV2/LV3 先验证业务场景准入；显式设置 AUTO_STOP_WHEN_APP_TERMINATE，未获准保留应用内流程。 同步接入 CaptureSheet/ContinuousCapture、BackupService 和 ShoppingSessionService 的状态，分别完成 CAP-06、DATA-02、TODO-05 中的 LV2、LV1、LV3 展示及对应开关和帮助说明；核心业务不得反向依赖本任务。验收按 QV-10 及 docs/request.md 的同编号要求。
- [ ] T154 [US10] 【可选，默认不执行】在 docs/acceptance-results.md、docs/release-checklist.md、docs/platform-config-manifest.md 补本次选做扩展的需求结果、资格与签名真机证据，并按实际能力补隐私开关、帮助和平台声明；未选做或资格不符写“可选未实施/未验证”，不得勾选通过。仅所选扩展通过 QV-10 后才将其列入该版本交付，不改变已通过的核心版本结论。

**Checkpoint**：每项选做能力分别通过资格核验及 QV-10 才算完成；整组未实施也不影响核心版本。此处仅保留计划，没有执行开发、申请或动态测试。
