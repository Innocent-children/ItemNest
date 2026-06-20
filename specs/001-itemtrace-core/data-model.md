# 数据模型：ItemTrace 本地物品追踪核心闭环

**版本**：Phase 2 Schema v3（兼容 Phase 1 v1）  
**存储边界**：业务数据使用本地 RDB Store；轻量偏好使用 Preferences；图片文件仅存于应用私有目录，RDB 只保存其本地 Asset 标识与元数据。

## 领域模型

### Item（第一阶段核心实体）

| 字段 | 类型/范围 | 必填 | 规则与说明 |
|---|---|---:|---|
| `id` | 文本唯一标识 | 是 | 创建时生成，创建后不可改变；用于详情、编辑、删除与未来关联。 |
| `name` | 1–80 字符 | 是 | 去除首尾空白后不能为空。 |
| `quantity` | 非负数，最多两位小数 | 是 | 默认 `1`；`0` 表示待补货，不表示删除。 |
| `unit` | 个/盒/瓶/包/件/其他 | 是 | 默认“个”。 |
| `locationPath` | 最长 200 字符文本 | 否 | 单个路径文本，例如“厨房 / 冰箱 / 冷藏层”；不解析为层级。 |
| `category` | 固定分类之一 | 否 | 药品、食品、证件、工具、办公、生活用品、儿童用品、宠物用品、其他。 |
| `expirationDate` | 本地日期 | 否 | 每条 Item 最多一个日期；不由生产日期推导。 |
| `reminderDays` | 0–365 的整数 | 否 | 缺省时计算有效值为 7；Phase 1 不创建系统提醒。 |
| `notes` | 最多 500 字符 | 否 | 仅本地显示。 |
| `photoState` | `NONE` / `LOCAL` | 是 | `LOCAL` 表示当前物品关联应用私有目录内的活动图片。 |
| `photoLocalId` | Asset 标识 | 否 | v1 为 `NULL`；Phase 2 指向当前活动 `item_asset.id`，不保存相册外部 URI。 |
| `createdAt` | 毫秒时间戳 | 是 | 用于最近添加排序。 |
| `updatedAt` | 毫秒时间戳 | 是 | 每次成功更新后刷新。 |

### 派生值与状态

`ExpiryStatus` 不是数据库字段，每次查询和展示时按当前本地日期计算：

| 状态 | 条件 |
|---|---|
| `NO_EXPIRY_DATE` | `expirationDate` 为空。 |
| `EXPIRED` | 到期日期早于当前本地日期。 |
| `DUE_SOON` | 到期日期等于当天，或不晚于“当前日期 + 有效提醒天数”。 |
| `NORMAL` | 到期日期晚于提醒窗口。 |

`StockStatus` 在 v1 只用于首页待补货：`quantity = 0` 为 `OUT_OF_STOCK`，其余为 `AVAILABLE`。
低库存阈值、提醒和批次库存属于 Phase 3。

### 后续实体演进

| 阶段 | 实体 | 关系与迁移要点 |
|---|---|---|
| 2 | Asset | 当前实现为每个 Item 一个活动 Asset；保存私有路径、来源和创建时间。替换后尽力清理旧文件与元数据，迁移后兼容 v1 的 `photoState=NONE`。 |
| 2 | ReminderRecord | 当前实现为每个 Item 一条提醒协调记录；保存计划时间、外部任务标识、状态、错误摘要和最后协调时间。 |
| 3 | Location | 树形位置；迁移 Item 的 `locationPath` 至可选 `locationId`，保留原文本以便回滚或匹配。 |
| 3 | Category | 独立分类；迁移固定分类文本至 `categoryId`。 |
| 3 | Batch | 一对多关联 Item（T077），承载数量、到期日期和位置。v1 Item 的单日期/数量语义通过关联批次明确，详见下方批次迁移规则。 |
| 3 | TraceEvent | 关联 Item，记录借出、归还、数量调整和导入导出操作。 |

## RDB 表结构设计

### `item`（Schema v1，保持语义不变）

**实现同步（2026-06-20）**：当前 `RdbDatabase` 使用本地数据库 `itemtrace.db`，版本为 3；
v1 创建本表及本节列出的四个索引。v2、v3 只追加提醒与图片表，不改变 Item 的字段语义。

| 列 | 存储类型 | 约束 | 查询用途 |
|---|---|---|---|
| `id` | TEXT | 主键、非空 | 详情、更新、删除。 |
| `name` | TEXT | 非空 | 列表和名称部分匹配搜索。 |
| `quantity` | REAL | 非空、默认 1、非负 | 详情、待补货摘要。 |
| `unit` | TEXT | 非空、默认“个” | 列表和详情。 |
| `location_path` | TEXT | 可空 | 位置筛选与展示。 |
| `category` | TEXT | 可空 | 分类筛选与展示。 |
| `expiration_date` | TEXT | 可空，规范为本地日期字符串 | 到期排序与状态计算。 |
| `reminder_days` | INTEGER | 可空，0–365 | 到期状态计算。 |
| `notes` | TEXT | 可空 | 详情与编辑。 |
| `photo_state` | TEXT | 非空，v1 为 `NONE` | 详情入口状态。 |
| `photo_local_id` | TEXT | 可空，v1 为 NULL | Phase 2 兼容列。 |
| `created_at` | INTEGER | 非空 | 最近添加排序。 |
| `updated_at` | INTEGER | 非空 | 更新排序和诊断。 |

**索引**：`created_at`（最近添加）、`location_path`（位置筛选）、`category`（分类筛选）、
`expiration_date`（临期排序）。v1 不引入全文搜索；规格的 50 条数据规模下，名称部分匹配
保持简单。若实际数据规模或性能验证显示不足，再以独立迁移评估索引或搜索方案。

**扫码边界**：Schema v1 与第二阶段均不新增物品编码列。扫码结果只是用户确认前的临时文本，
可预填备注或搜索条件；如需持久化编码，必须先增加独立规格、字段迁移、唯一性规则和验收用例。

### `reminder_record`（Schema v2）

| 列 | 存储类型 | 约束/说明 |
|---|---|---|
| `item_id` | TEXT | 主键；每个 Item 当前最多一条协调记录。 |
| `scheduled_at` | INTEGER | 可空；本地 09:00 的计划毫秒时间戳。 |
| `system_reminder_id` | INTEGER | 可空；HarmonyOS Reminder Manager 返回的外部任务标识。 |
| `status` | TEXT | `SCHEDULED`、`FAILED`、`CANCELLED`、`NOT_REQUIRED`。 |
| `error_summary` | TEXT | 可空、面向用户的短错误说明；不记录原始系统堆栈。 |
| `updated_at` | INTEGER | 最近协调时间戳。 |

索引：`status`、`scheduled_at`。提醒系统不可用或被拒绝时 Item 仍然保存，记录写入 `FAILED`，详情页提供重试。

### `item_asset`（Schema v3）

| 列 | 存储类型 | 约束/说明 |
|---|---|---|
| `id` | TEXT | 主键；应用生成的 Asset 标识。 |
| `item_id` | TEXT | 关联 Item；当前 UI 使用 `photo_local_id` 指向活动图片。 |
| `local_path` | TEXT | 应用 `filesDir/itemtrace-assets/` 内路径；不保存系统相册 URI。 |
| `source` | TEXT | `PHOTO_PICKER` 或 `SYSTEM_CAMERA`。 |
| `created_at` | INTEGER | 写入私有目录后的创建时间。 |

索引：`item_id`、`created_at`。图片二进制不进入 RDB；选择器取消、复制失败或相机入口不可用时，保留旧图片和表单草稿。

### 数据库初始化与迁移

1. 数据库首次打开时在同一事务中按顺序创建 Schema v1（`item`）、v2（`reminder_record`）和 v3（`item_asset`），随后写入当前数据库版本。
2. 已存在 v1 数据库仅执行 v2 与 v3 的追加建表/索引；已存在 v2 数据库仅执行 v3。每次升级按版本顺序在事务中执行：检查当前版本 → 执行单个迁移 → 校验表/索引 → 提交版本。
3. 任一迁移失败时回滚该事务，保留旧版数据并返回“数据库初始化失败”；页面不得显示为初始化成功。
4. 每个迁移必须提供：样本旧数据、升级验证、失败验证、回退策略和数据模型文档更新。
5. 删除 Item 前先取消已知系统提醒；删除 `item` 行后尽力清理关联图片文件和 Asset 元数据。清理失败不回滚已经成功的用户删除，后续版本应增加可恢复清理队列。

## Repository 与 DAO 边界

| 层 | 职责 | 禁止事项 |
|---|---|---|
| `RdbDatabase` | 打开/关闭、版本、迁移、事务与初始化错误转换。 | 不包含 Item 业务判断或页面状态。 |
| `ItemDao` | 参数化写入、按 ID 查询、条件查询、删除和行映射。 | 不计算到期状态，不显示用户文案。 |
| `ItemRepository` | 域对象转换、查询语义、写操作原子性和领域错误。 | 不直接操作页面或系统提醒。 |
| `ItemService` | 创建/编辑/删除用例、输入校验、摘要组装与刷新协调。 | 不拼接 SQL，不访问 ArkUI 组件。 |
| `ExpiryService` | 根据 Item 和本地日期计算 `ExpiryStatus`/`StockStatus`。 | 不持久化派生状态。 |

## 数据完整性与删除规则

- 创建/编辑前验证名称、数量、单位、提醒天数、注意事项长度和到期日期格式。失败时不得写入。
- `id`、`createdAt` 创建后不可被编辑；更新仅改变允许字段和 `updatedAt`。
- 删除只在 UI 明确确认后调用 Repository；v1 不提供回收站或恢复。
- 本地数据不会被上传；日志和错误提示不得包含注意事项、位置完整路径、图片标识或全量物品内容。
- Phase 2 图片与提醒任务不是 Item 保存成功的前置条件。系统能力失败时，Item 及其到期状态仍保留，并以列表提示或详情状态提供重试。


### Phase 3 批次迁移规则（T077）

v1 的 Item 有一组单一的数量、到期日与位置。引入 Batch 后，每个 Item 可拥有零个、一个或多个 Batch：

- 存量 v1 Item 自动创建一个等价 Batch（称为"默认批次"），其 quantity、expirationDate、locationPath 从对应 Item 字段复制。
- 默认批次创建后，Item 的 quantity 变为所有非零数量批次的 SUM(batch.quantity)（若全部为零则为 0），Item 的 expirationDate 显示最早到期批次的日期，locationPath 保持原文本直至 T084 迁移为 locationId。
- 迁移在单事务内完成：创建 batch 表 -> 为每个 v1 Item 插入一条默认批次 -> 更新数据模型版本 -> 提交。
- 回滚规则：迁移失败回滚整个事务，v1 数据完全保留，Item 字段不改变。
- 验收：v1 50 条 Item 样本迁移后每个 Item 有且仅有一个默认批次；迁移失败时 v1 数据库完整可用。
