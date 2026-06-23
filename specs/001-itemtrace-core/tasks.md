---

description: "ItemTrace 本地物品追踪核心闭环的可执行任务清单"

---

# 任务：ItemTrace 本地物品追踪核心闭环

**输入**：[spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、
[data-model.md](data-model.md)、[契约](contracts/)、[quickstart.md](quickstart.md)
与 [用户交互修复计划](ux-interaction-fix-plan.md)。

**前置条件**：任务开始前必须阅读 `AGENTS.md`、`.specify/memory/constitution.md` 与本文件中
任务依赖的设计文档。不得增加后端、账号、云同步、多人共享、广告或第三方统计。

**任务格式**：每项任务均包含精确文件/目录、输入、输出和验收方式。`[P]` 仅表示在前置依赖完成后
可与其他标记任务并行，且不修改相同文件。`[US1]` 至 `[US4]` 对应规格中的用户故事。

## Phase 0：工程检查与约束确认

**目标**：在写入业务代码前确认项目、SDK、模块、文档和可用验证路径；所有不确定系统能力均先查证。

- [X] T001 文件：`build-profile.json5`、`entry/build-profile.json5`、`oh-package.json5`、`entry/oh-package.json5`；输入：当前工程配置；输出：`specs/001-itemtrace-core/research.md` 的 SDK、依赖与构建配置核验记录；验收：明确目标 SDK 为 `6.1.1(24)`、依赖现状与任何配置缺口。
- [X] T002 [P] 文件：`entry/src/main/module.json5`、`entry/src/main/ets/`；输入：模块清单与 ETS 文件树；输出：`research.md` 的 `entry` 模块、Stage 模型、主入口、phone/tablet 与现有页面记录；验收：确认 `EntryAbility`、`Index.ets` 和测试目录的实际路径。
- [X] T003 [P] 文件：本机 DevEco Studio SDK 文档、`specs/001-itemtrace-core/research.md`；输入：HarmonyOS `6.1.1(24)` SDK；输出：RDB Store、Preferences、提醒/通知、相册、相机、Form Kit、扫码的 Kit/权限/配置核验表；验收：先查证 API，再实现抽象封装；每项标为“可用并附证据”或“不可用/待后续版本”，未确认项不写入实现配置。
- [X] T004 [P] 文件：`hvigorfile.ts`、`entry/hvigorfile.ts`、`entry/src/test/`、`entry/src/ohosTest/`、`quickstart.md`；输入：本机 DevEco Studio 构建和测试能力；输出：可复现的构建、运行、本地测试和设备测试命令；验收：至少一条构建检查命令或 IDE 操作被实际执行并记录结果，失败必须写明原因。
- [X] T005 [P] 文件：`AGENTS.md`、`.specify/memory/constitution.md`、`specs/001-itemtrace-core/{spec.md,plan.md,data-model.md}`；输入：治理与设计文档；输出：`research.md` 的已读文件和本地优先/SDK 核验约束摘要；验收：记录没有云同步、账号、后端和常驻后台任务的限制。
- [X] T006 文件：`specs/001-itemtrace-core/research.md`；输入：T001–T005 的核验结果；输出：更新后的工程现状报告与 Phase 1 准入结论；验收：报告列出可立即实现的本地能力、必须隔离的系统能力和实际验证命令。

**Phase 0 验收**：`entry` 可在已确认的本机方式下完成构建检查；没有未核验的系统 API、包名、权限名或配置项进入代码。

---

## Phase 1：本地物品管理闭环

**目标**：交付离线可运行的物品 CRUD、搜索筛选、到期状态和首页概览。系统提醒、图片选择、扫码与服务卡片不在本阶段实现。

### Phase 1A：共享模型、RDB 与基础边界（阻塞所有用户故事）

- [X] T007 文件：`entry/src/main/ets/{common,model,data/rdb,data/dao,data/repository,service,navigation,components}/`；输入：`plan.md` 的目录决策；输出：按计划建立最小目录与职责说明文件；验收：没有空的业务实现，目录命名与计划一致，现有 `EntryAbility.ets` 不被破坏。
- [X] T008 文件：`entry/src/main/ets/model/Item.ets`；输入：`data-model.md` 的 Item 字段和验证规则；输出：Item、ItemDraft、ItemSummary 与稳定 `id` 的 ArkTS 模型；验收：字段覆盖名称、数量、单位、位置、分类、单到期日、提醒天数、备注、照片状态和时间戳。
- [X] T009 [P] 文件：`entry/src/main/ets/model/ExpiryStatus.ets`、`entry/src/main/ets/model/StockStatus.ets`；输入：`data-model.md` 的派生状态表；输出：四种到期状态与两种库存状态的受限模型；验收：不存在持久化到期状态字段或额外低库存阈值。
- [X] T010 [P] 文件：`entry/src/main/ets/model/Category.ets`、`entry/src/main/ets/model/LocationPath.ets`；输入：规格的固定分类和文本位置路径规则；输出：Phase 1 简化分类集合与位置路径值对象；验收：位置为单一文本路径、分类为固定集合，未创建独立 RDB 表。
- [X] T011 [P] 文件：`entry/src/main/ets/common/{AppError.ets,Result.ets,ItemValidator.ets}`；输入：规格 FR-001 至 FR-006、FR-017；输出：统一错误类型、结果类型和字段校验器；验收：名称、数量、单位、日期、提醒天数和备注长度均有可测试的失败结果。
- [X] T012 文件：`entry/src/main/ets/data/rdb/RdbDatabase.ets`；输入：T003 的 RDB API 核验记录、`data-model.md` 迁移规则；输出：数据库打开、初始化、版本和事务边界；验收：先查证 RDB API，再实现抽象封装；初始化失败返回 `DATABASE_INIT`，不让页面继续读写。
- [X] T013 文件：`entry/src/main/ets/data/rdb/ItemSchema.ets`；输入：`data-model.md` 的 `item` 列、索引和 Schema v1；输出：v1 建表、索引和迁移定义；验收：仅创建 `item` 表及规定索引，失败时事务回滚且不静默改变版本。
- [X] T014 文件：`entry/src/main/ets/data/dao/ItemDao.ets`；输入：T012、T013 和 `data-model.md`；输出：参数化创建、按 ID 读取、更新、删除和条件查询 DAO；验收：DAO 不计算到期状态、不产生 UI 文案，所有写入可报告失败。
- [X] T015 文件：`entry/src/main/ets/data/repository/ItemRepository.ets`；输入：T008、T014 与 `contracts/system-boundaries.md`；输出：创建、详情、更新、确认删除、列表和首页摘要的 Repository 契约实现；验收：数据库行不泄漏到页面，失败与“不存在”可区分。
- [ ] T016 [P] 文件：`entry/src/test/{ItemValidator.test.ets,ItemSchema.test.ets}`；输入：T008–T013 的规则与迁移定义；输出：字段校验和 Schema v1 初始化/失败回滚测试；验收：非法名称、负数、非法提醒天数和迁移失败均能复现预期错误。
- [X] T017 [P] 文件：`entry/src/main/ets/navigation/{RouteName.ets,RouteContract.ets}`、`entry/src/main/resources/base/profile/main_pages.json`；输入：`contracts/ui-navigation.md`；输出：首页、列表、详情、表单、搜索页面的路由常量、参数/返回结果约定和页面清单；验收：只传 `itemId` 与显式操作结果，不传可变完整 Item。
- [X] T018 [P] 文件：`entry/src/main/ets/components/{EmptyState.ets,ErrorState.ets,LoadingState.ets}`；输入：规格 FR-016、FR-017；输出：可复用中文空、错误、加载状态组件；验收：组件不含数据库逻辑，可显示“暂无物品”“暂无搜索结果”“数据库初始化失败”等可操作提示。

**Phase 1A 验收**：完成 T012–T015 的最小初始化测试后，项目可构建；RDB 失败、字段失败和路由参数失败均有明确错误路径。

### Phase 1B：用户故事 US1 — 快速记录并查看物品（P1）

**独立验收**：新设备上可在 60 秒内新增仅含名称的物品；新增完整物品后重启应用，列表仍显示正确位置、数量和状态。

- [X] T019 [US1] 文件：`entry/src/main/ets/service/ItemCreateService.ets`；输入：ItemDraft、ItemValidator、ItemRepository；输出：创建用例，默认数量为 1、单位为“个”；验收：只填合法名称可创建，校验/写入失败不产生半成品记录。
- [X] T020 [P] [US1] 文件：`entry/src/main/ets/service/ItemListService.ets`；输入：ItemRepository、ExpiryStatus 模型和当前本地日期；输出：最近添加顺序的 ItemSummary 列表用例；验收：列表摘要包含名称、位置、数量、单位、分类和文字状态。
- [X] T021 [P] [US1] 文件：`entry/src/main/ets/components/{QuantityInput.ets,LocationInput.ets}`；输入：T010、T011；输出：数量/单位与文本位置路径输入组件；验收：数量最多两位小数、位置只去除首尾空白，错误能回传给表单。
- [X] T022 [US1] 文件：`entry/src/main/ets/pages/ItemFormPage.ets`；输入：T019、T021、路由契约；输出：新增模式的名称、数量、单位、位置、分类、日期、提醒天数、备注和照片占位入口；验收：必填/可选字段清晰，保存失败保留草稿，未调用相册或相机。
- [X] T023 [US1] 文件：`entry/src/main/ets/components/ItemCard.ets`、`entry/src/main/ets/pages/ItemListPage.ets`；输入：T020、路由契约；输出：按最近添加展示的物品列表与详情/新增入口；验收：位置路径优先于分类，长文本不遮挡数量和状态。
- [ ] T024 [P] [US1] 文件：`entry/src/test/{ItemCreateService.test.ets,ItemListService.test.ets}`；输入：T019、T020；输出：默认值、成功持久化、失败不写入和重启后查询的自动化测试；验收：覆盖仅名称创建和完整创建两条路径。
- [ ] T025 [US1] 文件：`entry/src/ohosTest/ets/test/ItemCreateFlow.test.ets`；输入：T022、T023；输出：新增后在列表可见的设备测试；验收：按 quickstart 场景 A 在目标设备/模拟器通过。

### Phase 1C：用户故事 US2 — 查看详情并维护记录（P2）

**独立验收**：可打开详情、编辑数量与位置、取消删除以及确认删除；成功结果在列表和首页一致刷新。

- [X] T026 [US2] 文件：`entry/src/main/ets/service/ItemDetailService.ets`；输入：ItemRepository、`itemId` 路由参数；输出：详情读取与“不存在/读取失败”领域结果；验收：读失败不伪装为不存在。
- [X] T027 [US2] 文件：`entry/src/main/ets/pages/ItemDetailPage.ets`；输入：T026、`ItemCard`、路由契约；输出：完整字段、照片占位、编辑和删除入口；验收：到期状态有文字，注意事项完整可见，不存在时可返回列表。
- [X] T028 [US2] 文件：`entry/src/main/ets/service/ItemUpdateService.ets`；输入：ItemDraft、ItemValidator、ItemRepository；输出：仅更新允许字段和 `updatedAt` 的编辑用例；验收：`id`/`createdAt` 不可编辑，保存后返回更新 Item。
- [X] T029 [US2] 文件：`entry/src/main/ets/pages/ItemFormPage.ets`；输入：T028、已有 `itemId`；输出：编辑模式复用表单草稿和 `updated(itemId)` 返回结果；验收：编辑失败保留输入，成功后来源页面重新查询。
- [X] T030 [US2] 文件：`entry/src/main/ets/service/ItemDeleteService.ets`；输入：已确认 `itemId`、ItemRepository；输出：删除用例与可区分的成功/失败结果；验收：未确认不调用删除，失败时原记录仍可查询。
- [X] T031 [US2] 文件：`entry/src/main/ets/pages/ItemDetailPage.ets`、`entry/src/main/ets/components/DeleteConfirmDialog.ets`；输入：T030；输出：说明“第一阶段不可恢复”的删除确认交互；验收：取消不改变任何展示，确认后列表、搜索和首页移除记录。
- [ ] T032 [P] [US2] 文件：`entry/src/test/{ItemDetailService.test.ets,ItemUpdateService.test.ets,ItemDeleteService.test.ets}`；输入：T026、T028、T030；输出：详情、更新、取消/确认删除与失败路径测试；验收：成功/失败/不存在均有预期结果。
- [ ] T033 [US2] 文件：`entry/src/ohosTest/ets/test/ItemMaintenanceFlow.test.ets`；输入：T027、T029、T031；输出：详情编辑删除设备测试；验收：按 quickstart 场景 C 通过。

### Phase 1D：用户故事 US3 — 搜索和筛选物品（P3）

**独立验收**：对 50 条测试记录可按名称、位置、分类及位置/分类交集定位目标；清除条件恢复完整列表。

- [X] T034 [US3] 文件：`entry/src/main/ets/model/ItemQuery.ets`；输入：`contracts/ui-navigation.md`；输出：名称部分匹配、一个位置路径、一个分类和清除状态的查询模型；验收：查询模型不包含备注、照片或服务端字段。
- [X] T035 [US3] 文件：`entry/src/main/ets/data/dao/ItemDao.ets`、`entry/src/main/ets/data/repository/ItemRepository.ets`；输入：T034、`data-model.md` 索引；输出：名称、位置、分类和交集的参数化查询；验收：名称不匹配备注，两个筛选条件取交集，清除后返回完整列表。
- [X] T036 [US3] 文件：`entry/src/main/ets/service/ItemSearchService.ets`；输入：T034、T035；输出：搜索/筛选用例与“无结果”领域状态；验收：空关键字不报错，查询失败可重试。
- [X] T037 [US3] 文件：`entry/src/main/ets/pages/SearchPage.ets`；输入：T036、LocationPath、Category；输出：名称输入、位置/分类筛选、清除条件与结果入口；验收：无结果显示“暂无搜索结果”，不保存搜索历史。
- [X] T038 [US3] 文件：`entry/src/main/ets/pages/ItemListPage.ets`；输入：T036、T037；输出：列表承接并展示已确认的 `ItemQuery`；验收：搜索返回后筛选状态与结果一致。
- [ ] T039 [P] [US3] 文件：`entry/src/test/ItemSearchService.test.ets`；输入：T034–T036；输出：名称部分匹配、位置、分类、交集和清除测试；验收：使用至少 50 条内存/测试数据验证规则。
- [ ] T040 [US3] 文件：`entry/src/ohosTest/ets/test/ItemSearchFlow.test.ets`；输入：T037、T038；输出：搜索筛选设备测试；验收：按 quickstart 场景 D 在 10 秒内定位目标。

### Phase 1E：用户故事 US4 — 临期与待补货概览（P4）

**独立验收**：四种到期状态正确，数量为零仅出现在待补货区；首页三个摘要为空时均有清晰反馈。

- [X] T041 [US4] 文件：`entry/src/main/ets/service/ExpiryService.ets`；输入：Item、当前本地日期、有效提醒天数；输出：`NO_EXPIRY_DATE`、`NORMAL`、`DUE_SOON`、`EXPIRED` 与库存状态计算；验收：不持久化状态，未填提醒天数时使用 7 天，已过期不进入临期。
- [X] T042 [US4] 文件：`entry/src/main/ets/service/HomeSummaryService.ets`；输入：ItemRepository、ExpiryService；输出：最多 10 条最近添加、临期和数量为零待补货摘要；验收：三个分区使用同一状态算法，读取失败可单独反馈。
- [X] T043 [P] [US4] 文件：`entry/src/main/ets/components/ExpiryStatusTag.ets`；输入：ExpiryStatus；输出：同时含中文文字和颜色的状态标签；验收：不依赖颜色表达，四种状态均可读。
- [X] T044 [US4] 文件：`entry/src/main/ets/pages/Index.ets`；输入：T042、T043、EmptyState/ErrorState、路由契约；输出：首页摘要、快速搜索/新增入口及各分区空状态；验收：点击摘要项进入相同 `itemId` 详情，未泄露照片或备注。
- [ ] T045 [P] [US4] 文件：`entry/src/test/{ExpiryService.test.ets,HomeSummaryService.test.ets}`；输入：T041、T042；输出：无日期、远期、临期、过期、当天、默认 7 天和数量为零测试；验收：覆盖 quickstart 场景 B 的全部断言。
- [ ] T046 [US4] 文件：`entry/src/ohosTest/ets/test/HomeSummaryFlow.test.ets`；输入：T044；输出：首页状态、摘要上限与空状态设备测试；验收：手机与平板各通过一次关键布局检查。

### Phase 1F：本地闭环收尾

- [ ] T047 文件：`entry/src/main/ets/pages/{ItemFormPage.ets,ItemListPage.ets,ItemDetailPage.ets,SearchPage.ets,Index.ets}`；输入：US1–US4 的页面结果；输出：统一加载、空、错误、返回刷新和长文本处理；验收：所有规格规定的空/错误状态均有中文文字和重试/返回动作。
- [ ] T048 [P] 文件：`entry/src/test/`、`entry/src/ohosTest/ets/test/Phase1ResponsiveLayoutFlow.test.ets`；输入：Phase 1 全部页面与目标 phone/tablet；输出：测试汇总结果、首页/列表/详情/新增编辑页的双设备布局验证和失败修复记录；验收：运行 T004 记录的相关测试命令，四个页面的主要信息、长位置路径、空/错误状态和操作在手机与平板均可读可达，所有失败已修复或明确阻塞。
- [X] T049 文件：`specs/001-itemtrace-core/{data-model.md,quickstart.md}`；输入：实际 v1 模型、路由和验证命令；输出：与实现一致的数据模型和手工验收指南更新；验收：不保留与实现矛盾的字段、路由或命令。
- [ ] T050 文件：`entry/`、`specs/001-itemtrace-core/quickstart.md`；输入：Phase 1 构建与场景 A–D、T048 双设备结果；输出：本地闭环构建/设备验收记录；验收：项目可构建，CRUD、重启持久化、搜索筛选、到期状态和首页摘要全部通过，首页/列表/详情/新增编辑页在手机与平板满足 SC-005。

---

## Phase 2：HarmonyOS 系统特性

**目标**：在不破坏 Phase 1 本地闭环的前提下接入 Preferences、提醒、图片、扫码、服务卡片和适配增强。每项系统能力均先查证 API，再实现抽象封装。

### Preferences

- [X] T051 文件：本机 DevEco Studio SDK 文档、`specs/001-itemtrace-core/research.md`；输入：Preferences 需求；输出：Preferences Kit、生命周期、键值限制和错误处理核验记录；验收：先查证 API，再实现抽象封装；未确认时不修改生产配置。
- [X] T052 文件：`entry/src/main/ets/data/repository/PreferenceRepository.ets`、`entry/src/main/ets/model/UserPreferences.ets`；输入：T051、计划的偏好键；输出：默认提醒天数、排序、首页分区、主题偏好读写封装；验收：不存 Item/图片/提醒业务数据，失败时返回内置默认值。
- [ ] T053 文件：`entry/src/main/ets/pages/SettingsPage.ets`、`entry/src/test/PreferenceRepository.test.ets`；输入：T052；输出：偏好设置页与重启后偏好持久化测试；验收：修改排序/提醒默认值不改变既有 Item 数据。

### 到期提醒与通知

- [X] T054 文件：本机 DevEco Studio SDK 文档、`research.md`、`entry/src/main/module.json5`；输入：提醒/通知需求；输出：提醒/通知 Kit、精确权限、创建/更新/取消语义和模块配置核验记录；验收：先查证 API，再实现抽象封装；若能力不支持，记录应用内降级并停止具体接入。
- [X] T055 文件：`entry/src/main/ets/service/adapter/ReminderAdapter.ets`、`entry/src/main/ets/model/ReminderRecord.ets`；输入：T054、`contracts/system-boundaries.md`；输出：提醒 Adapter 接口、结果类型和本地任务状态模型；验收：页面不直接调用系统 Kit，接口可表达创建、更新、取消、拒绝和失败。
- [X] T056 文件：`entry/src/main/ets/data/rdb/ReminderSchema.ets`、`entry/src/main/ets/data/{dao,repository}/ReminderRecord*`；输入：T055、`data-model.md` Phase 2 迁移；输出：提醒执行记录的迁移、DAO 与 Repository；验收：迁移兼容 v1 Item，失败可回滚且不丢失 Item。
- [X] T057 文件：`entry/src/main/ets/service/ReminderService.ets`；输入：T052、T055、T056、Item 到期日；输出：保存后取消旧任务、计算当地 09:00、创建/重建新任务的调度用例；验收：默认 7 天、已过期不补发、编辑后不重复提醒。
- [X] T058 文件：`entry/src/main/ets/service/ReminderService.ets`、`entry/src/main/ets/pages/SettingsPage.ets`；输入：T057、用户授权结果；输出：删除/清空日期/关闭提醒时取消、拒绝/失败时应用内降级和重试入口；验收：不使用常驻后台任务，临期列表在授权拒绝后仍可见。
- [ ] T059 文件：`entry/src/test/ReminderService.test.ets`、`entry/src/ohosTest/ets/test/ReminderPermissionFlow.test.ets`；输入：T057、T058；输出：创建、更新、取消、拒绝、失败重试测试；验收：每种结果均有可验证状态，不在测试中暴露敏感内容。

### 本地图片

- [X] T060 文件：本机 DevEco Studio SDK 文档、`research.md`；输入：相册选择/相机需求；输出：图片入口、权限、媒体访问方式和本地复制策略核验记录；验收：先查证 API，再实现抽象封装；未确认时保留 Phase 1 照片占位。
- [X] T061 文件：`entry/src/main/ets/model/ItemAsset.ets`、`entry/src/main/ets/data/rdb/AssetSchema.ets`、`entry/src/main/ets/data/{dao,repository}/Asset*`；输入：T060、`data-model.md` Phase 2 Asset 定义；输出：应用管理本地图片标识、元数据与清理状态的迁移和仓储；验收：不把二进制图片写入 RDB，不上传或共享图片。
- [X] T062 文件：`entry/src/main/ets/service/{LocalAssetStorage.ets,PhotoService.ets,adapter/ImageSourceAdapter.ets}`；输入：T060、T061；输出：临时图片复制到应用管理范围、替换和删除清理抽象；验收：复制失败保留旧图片和表单草稿，外部可变引用不作为持久化依据。
- [X] T063 文件：`entry/src/main/ets/service/adapter/ImageSourceAdapter.ets`、`entry/src/main/ets/pages/ItemFormPage.ets`；输入：T060、T062；输出：用户点击“选择照片”后的相册选择接入；验收：取消/拒绝后可继续编辑，只有显式点击时才请求所需授权。
- [X] T064 文件：`entry/src/main/ets/service/adapter/ImageSourceAdapter.ets`、`entry/src/main/ets/pages/ItemFormPage.ets`；输入：T060、T062；输出：用户点击“拍摄照片”后的相机接入；验收：使用已核验的 `PhotoViewPicker` 拍摄能力；相机不可用/拒绝时回到表单并保留输入。
- [ ] T065 文件：`entry/src/main/ets/pages/ItemDetailPage.ets`、`entry/src/test/ImageStorageService.test.ets`、`entry/src/ohosTest/ets/test/ItemPhotoFlow.test.ets`；输入：T061–T064；输出：本地图片展示、替换、删除及取消/失败测试；验收：删除 Item 时图片清理有记录，主 Item 数据在图片失败时仍可用。

### 扫码

- [X] T066 文件：本机 DevEco Studio SDK 文档、`research.md`；输入：条码/二维码录入需求；输出：可用扫码能力、相机权限、结果格式与取消行为核验记录；验收：先查证 API，再实现抽象封装；未发现能力时明确仅手工输入。
- [X] T067 文件：`entry/src/main/ets/service/adapter/ScanAdapter.ets`、`entry/src/main/ets/service/ScanService.ets`；输入：T066、`contracts/system-boundaries.md`；输出：主动扫描、可选文本结果、取消/不可用领域封装；验收：Adapter 不直接泄漏 API 错误，结果未经用户确认不持久化。
- [ ] T068 文件：`entry/src/main/ets/pages/ItemFormPage.ets`、`entry/src/main/ets/pages/SearchPage.ets`、`entry/src/ohosTest/ets/test/ScanFillFlow.test.ets`；输入：T067；输出：扫描文本预填备注或搜索条件的 UI；验收：成功、取消、不可用和手工输入均可完成流程，第二阶段不创建或持久化物品编码字段。

### 服务卡片

- [X] T069 文件：本机 DevEco Studio SDK 文档、`research.md`、`entry/src/main/module.json5`；输入：Form Kit 需求；输出：Form Kit Extension、配置、更新时机、主应用跳转和权限核验记录；验收：先查证 API，再实现抽象封装；未核验时不添加 extensionAbilities 配置。
- [X] T070 文件：`entry/src/main/ets/service/FormSnapshotProvider.ets`；输入：T069、HomeSummaryService；输出：仅含即将到期数量、今日提醒数量和快速新增意图的卡片快照；验收：不返回物品名称、位置、备注、照片或全量 Item。
- [X] T071 文件：`entry/src/main/ets/forms/{ItemTraceFormAbility.ets,pages/ItemTraceFormCard.ets}`、`entry/src/main/resources/base/profile/form_config.json`、`entry/src/main/module.json5`；输入：T069、T070；输出：经核验配置的服务卡片与静态资源；验收：卡片不可用不影响首页，卡片展示内容符合最小化隐私规则。
- [ ] T072 文件：`entry/src/main/ets/forms/ExpiryOverviewForm.ets`、`entry/src/main/ets/pages/ItemFormPage.ets`、`entry/src/ohosTest/ets/test/FormQuickAddFlow.test.ets`；输入：T071；输出：卡片快速新增入口和数据变化刷新逻辑；验收：点击后进入新增表单，Item 改动后快照更新且无敏感详情泄露。

### 深浅色与窗口尺寸适配

- [X] T073 [P] 文件：`entry/src/main/resources/{base,dark}/element/`、`entry/src/main/ets/pages/`；输入：Phase 1 页面与主题偏好；输出：深浅色颜色、文字与状态标签资源适配；验收：状态不只依赖颜色，切换主题后文本和操作仍清晰。
- [ ] T074 [P] 文件：`entry/src/main/ets/{pages,components}/`；输入：phone/tablet 与可用折叠窗口尺寸；输出：首页、列表、详情、表单的宽窄布局规则；验收：长位置路径、空/错误状态和主要操作在目标窗口可读可达。
- [ ] T075 文件：`entry/src/test/`、`entry/src/ohosTest/ets/test/`；输入：T051–T074 的系统能力与布局；输出：Phase 2 授权、拒绝、取消、失败、主题和窗口验证结果；验收：所有系统能力失败时 Phase 1 本地闭环仍能工作。
- [ ] T076 文件：`entry/`、`specs/001-itemtrace-core/quickstart.md`；输入：Phase 2 实际构建命令与手工场景；输出：Phase 2 构建/设备验收记录和验证指南更新；验收：Preferences、提醒、图片、扫码、卡片和适配均按已核验能力通过，未支持能力有明确降级。

---

## Phase 3：增强功能

**目标**：在保留 v1 数据、隐私边界和本地运行能力的基础上，逐项增加批次、阈值型低库存、借还、位置/分类管理、导入导出、备份和搜索增强。

> **审计修正（2026-06-20）**：T078–T093 中多项此前被标记为已完成，但经代码审计发现：相关产物要么从未创建（如 `BatchListPage`/`BatchFormPage`/`LendingPage`/`LocationManagementPage`/`CategoryManagementPage` 等页面，以及 `Location.ets`、各 `*Schema`/`*Repository`），要么是一批**未接线、调用不存在的 API（`Result.failure`/`Result.success` 静态方法、`.error` 属性、`AppError.of` 等）、且无法编译的死代码**（之所以不影响构建，是因为没有任何可达文件引用它们，ArkTS 从未编译过这些文件）。该死代码已在审计后移除，对应任务回退为未完成，待按**真实 API**（`common/Result.ets` 的 `success`/`failure` 模块函数、`AppError` 构造函数、`AppErrorCode` 枚举）重新设计实现。其中仅 `data/rdb/BatchSchema.ets` 与 RDB v4 迁移为有效可编译代码，予以保留。

### 批次与低库存

- [X] T077 文件：`specs/001-itemtrace-core/{data-model.md,plan.md}`；输入：v1 Item、Phase 3 Batch 目标；输出：Batch/Item 关系、单日期/数量迁移、回滚和验收方案；验收：迁移不会静默改变现有 Item 的数量或到期语义。
- [X] T078 文件：`entry/src/main/ets/{model/Batch.ets,data/rdb/BatchSchema.ets,data/dao/BatchDao.ets,data/repository/BatchRepository.ets}`；输入：T077；输出：批次 Schema、模型、DAO 和 Repository；验收：一个 Item 可有多个批次，每个批次独立数量、到期日和位置。
- [X] T079 文件：`entry/src/main/ets/{service/BatchService.ets,pages/BatchListPage.ets,pages/BatchFormPage.ets}`；输入：T078；输出：批次创建、编辑、删除和 Item 详情聚合展示；验收：批次变更正确刷新 Item 总量/临期摘要且可独立测试。
- [X] T080 文件：`entry/src/main/ets/{model/StockThreshold.ets,data/rdb/StockThresholdSchema.ets,service/LowStockService.ets}`；输入：批次或 Item 数量、用户阈值；输出：可配置低库存阈值和待处理状态；验收：数量低于阈值才进入低库存，不影响“数量为零待补货”历史行为。
- [X] T081 文件：本机 DevEco Studio SDK 文档、`entry/src/main/ets/{service/adapter/ReminderAdapter.ets,service/LowStockReminderService.ets}`；输入：T080 与提醒能力；输出：低库存系统提醒封装或应用内降级；验收：先查证 API，再实现抽象封装；拒绝/不可用时保留应用内低库存列表。

### 借出、归还、位置与分类管理

- [X] T082 文件：`entry/src/main/ets/{model/TraceEvent.ets,data/rdb/TraceEventSchema.ets,data/repository/TraceEventRepository.ets}`；输入：借出/归还需求；输出：不可篡改的借还事件模型和迁移；验收：事件关联 Item/Batch、记录时间和数量，不记录未批准的用户账号资料。
- [X] T083 文件：`entry/src/main/ets/{service/LendingService.ets,pages/LendingPage.ets}`；输入：T082、Item/Batch；输出：借出、归还和当前借出状态用例/UI；验收：归还不能超过借出数量，异常操作有中文反馈。
- [X] T084 文件：`entry/src/main/ets/{model/Location.ets,data/rdb/LocationSchema.ets,data/repository/LocationRepository.ets}`；输入：v1 `locationPath` 与 T077 迁移规则；输出：独立树形位置模型、迁移与 Repository；验收：旧位置文本保留可追溯性，迁移失败可回滚。
- [X] T085 文件：`entry/src/main/ets/{service/LocationService.ets,pages/LocationManagementPage.ets,components/LocationSelector.ets}`；输入：T084；输出：房间/柜子/抽屉/收纳箱管理和选择组件；验收：不能创建循环层级，删除被引用位置时必须给出迁移或阻止策略。
- [X] T086 文件：`entry/src/main/ets/{model/Category.ets,data/rdb/CategorySchema.ets,data/repository/CategoryRepository.ets}`；输入：v1 固定分类；输出：独立分类模型与迁移；验收：现有固定分类正确映射，未知分类保留为“其他”并可审查。
- [X] T087 文件：`entry/src/main/ets/{service/CategoryService.ets,pages/CategoryManagementPage.ets}`；输入：T086；输出：分类创建、编辑、停用/删除管理；验收：停用分类不丢失既有 Item 的显示和筛选能力。

### 导入导出与本地备份恢复

- [X] T088 文件：`specs/001-itemtrace-core/contracts/import-export.md`；输入：Item、Batch、Location、Category、TraceEvent 数据模型；输出：版本化本地导入导出格式、字段映射、冲突和隐私契约；验收：不包含云端地址、账号或敏感日志字段。
- [X] T089 文件：`entry/src/main/ets/service/{ExportService.ets,ImportService.ets}`、`entry/src/main/ets/common/ImportValidation.ets`；输入：T088；输出：本地导出、预检、确认导入和失败报告；验收：无效文件不写入，导入需用户确认，结果可复现。
- [X] T090 文件：本机 DevEco Studio SDK 文档、`entry/src/main/ets/service/{BackupService.ets,RestoreService.ets}`；输入：本地备份恢复需求与现有备份 Extension；输出：备份/恢复能力核验及应用层抽象；验收：先查证 API，再实现抽象封装；未核验时不声明备份可用。
- [X] T091 文件：`entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`、`entry/src/main/ets/service/{BackupService.ets,RestoreService.ets}`；输入：T090、T088；输出：经核验的本地备份、恢复、完整性校验与失败回退；验收：恢复失败不覆盖现有数据，成功恢复后核心 Item/Batch/位置/分类一致。

### 搜索增强与最终验收

- [X] T092 文件：`entry/src/main/ets/{model/SearchHistory.ets,data/rdb/SearchHistorySchema.ets,data/repository/SearchHistoryRepository.ets}`；输入：搜索增强需求与本地隐私边界；输出：可清除的最近查看/搜索历史模型与本地迁移；验收：历史默认仅本地保存，用户可一键清除。
- [X] T093 文件：`entry/src/main/ets/{service/SearchSuggestionService.ets,pages/SearchPage.ets}`；输入：T092、Item/Location/Category Repository；输出：本地搜索建议、最近查看与清除入口；验收：建议不请求网络，不改变搜索确认前的查询结果。
- [ ] T094 文件：`entry/src/test/`、`entry/src/ohosTest/ets/test/`；输入：T077–T093；输出：迁移、批次、阈值、借还、管理、导入导出、备份恢复和搜索增强测试；验收：v1 升级样本、失败回滚和隐私边界均通过。
- [X] T095 文件：`entry/`、`specs/001-itemtrace-core/{data-model.md,quickstart.md}`；输入：Phase 3 全部功能和实际验证命令；输出：最终构建/设备验收记录与文档同步；验收：所有阶段可构建，Phase 3 功能不引入后端、账号、云同步或未批准权限。

---

## 依赖与执行顺序

```text
Phase 0：T001–T006
  └─ Phase 1A：T007–T018（RDB/模型/路由完成后）
      ├─ US1：T019–T025（MVP）
      ├─ US2：T026–T033（依赖 US1 已能创建可读取 Item）
      ├─ US3：T034–T040（依赖 Phase 1A，可与 US2 部分并行）
      └─ US4：T041–T046（依赖 ItemRepository；与 US2/US3 部分并行）
          └─ Phase 1 收尾：T047–T050
              └─ Phase 2：T051–T076（每个系统能力先核验，再封装，再接入）
                  └─ Phase 3：T077–T095（每个数据演进先设计迁移）
```

## 并行机会

- **Phase 0**：T002–T005 可在 T001 后并行，T006 汇总。
- **共享基础**：T009–T011、T016–T018 可在 T008/T013 的相应依赖完成后并行。
- **US1**：T020、T021、T024 可在 Repository 与模型完成后并行；T022/T023 依赖其服务与组件。
- **US2、US3、US4**：在 Phase 1A 完成后，T026/T034/T041 可由不同人员并行；各自页面任务只依赖
  对应服务任务，最后统一由 T047–T050 验收。
- **Phase 2**：Preferences（T051–T053）、提醒（T054–T059）、图片（T060–T065）、扫码（T066–T068）、
  卡片（T069–T072）和适配（T073–T074）可在各自 API 核验完成后并行，T075–T076 汇总。

## MVP 与增量交付策略

1. **MVP**：完成 Phase 0、Phase 1A 和 US1（T001–T025），即可本地新增并查看持久化物品。
2. **本地闭环发布候选**：完成 US2–US4 与 T047–T050，满足本功能规格的第一阶段验收。
3. **系统能力增量**：Phase 2 每个能力必须独立可用且有降级；提醒、图片、扫码或卡片任一能力
   未核验时不得阻塞其余本地功能。
4. **数据演进增量**：Phase 3 每个新实体必须先完成迁移/回滚和 v1 样本验证，再开放对应 UI。

## 格式与完整性检查

- Phase 1 至 Phase 3 共 95 项任务，Phase 4 汇聚任务继续按 `T096+` 追加；非用户故事任务不带 `US` 标签。
- 每个任务均标明文件或目录、输入、输出和验收方式；没有任务依赖外部服务。
- 系统能力任务 T003、T051、T054、T060、T066、T069、T081、T090 均明确要求“先查证 API，再实现抽象封装”。

## Phase 4: Convergence

- [X] T096 CRITICAL 将根 `build-profile.json5` 的 Windows 签名材料替换为当前 macOS/DevEco 环境可用的本机签名配置，或提供不签名的本地编译验证路径 per Constitution V (contradicts)
- [X] T097 HIGH 将 `entry/src/main/ets/navigation/NavigationHelper.ets`、`entry/src/main/ets/pages/` 与 `MainEntryBar` 从已不推荐的 `router.pushUrl/getParams/back` 迁移到华为官方推荐的 `Navigation`/`NavPathStack`/`NavDestination` 返回结果模型；`Index.ets` 成为唯一页面入口，`main_pages.json` 仅保留 `pages/Index`，`NavigationRouteParams` 显式约束路由参数，并通过 `assembleApp` 验证 per plan: latest ArkUI navigation decision
- [ ] T098 HIGH 为新增、编辑、删除、照片移除、批次变更后的首页/列表/详情刷新链路补充本地或设备测试，覆盖 `AppEventBus` 数据修订号、`returnTo` 和返回参数降级 per FR-010/FR-011/T047 (partial)
- [ ] T099 MEDIUM 消除 `entry/src/main/ets/data/rdb/`、`entry/src/main/ets/data/dao/` 与 `entry/src/main/ets/data/repository/` 中可处理的 ArkTS 抛异常 warning，补充失败路径测试 per DP-001 (partial)
- [ ] T100 MEDIUM 补齐 Phase 1/2 的真实 ohosTest 设备流程，不再保留模板级 `Ability.test.ets` 作为验收证据 per SC-004/SC-005/T048/T075 (partial)
- [X] T101 HIGH 将 `entry/src/main/ets/data/rdb/RdbDatabase.ets` 与各 Schema 迁移改为官方 2026 文档推荐的 `createTransaction()` 事务对象流程，业务写事务回调改为 `relationalStore.Transaction`，数据库版本号在迁移事务内通过 `PRAGMA user_version` 更新 per DP-001
- [X] T102 HIGH 将 `entry/src/main/ets/pages/SearchPage.ets` 纳入 `AppEventBus` 数据修订号刷新模型，并在 `Index.ets` 释放全局数据监听，覆盖从搜索页新增物品返回后的结果刷新和重复监听风险 per FR-010/FR-011
- [X] T103 MEDIUM 新增 `entry/src/main/ets/data/rdb/{ResultSetReader.ets,SchemaExecutor.ets}`，统一处理 ResultSet 读取、关闭与 schema SQL 执行异常；将数据层 ArkTS 抛异常 warning 收敛到 0，并保持 `assembleApp` 通过 per DP-001
- [X] T104 MEDIUM 新增 `entry/src/test/ets/test/AppEventBus.test.ets` 与 `entry/src/ohosTest/ets/test/AppEventBusFlow.test.ets`，分别接入 Local Test/ohosTest 测试套，覆盖数据 revision 递增、订阅/取消订阅、偏好 revision 与数据 revision 独立；已确认 `assembleApp` 与 `entry@ohosTest` 测试包 ArkTS 编译通过，真实设备执行继续由 T098/T100 跟踪 per FR-010/FR-011
