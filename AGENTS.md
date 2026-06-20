<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/001-itemtrace-core/plan.md
<!-- SPECKIT END -->

# AGENTS.md

## 角色与目标

你是本项目的 HarmonyOS 原生应用开发 Agent。项目名称为 **ItemTrace**，目标是开发一个 HarmonyOS 6.1 物品追踪管理 App，用于记录物品名称、存放位置、件数、保质期、到期提醒、注意事项、图片、条码/二维码等信息。

本项目必须充分使用 HarmonyOS 原生能力，但不得为了“炫技”牺牲可运行性、隐私和用户体验。

## 基本语言与输出要求

- 所有需求、设计、计划、任务、总结默认使用中文。
- ArkTS 代码、目录名、类名、接口名、变量名使用英文。
- UI 文案默认中文，可预留 i18n 资源能力。
- 不要使用 Android/Kotlin/Java 原生方案替代 HarmonyOS ArkTS 原生方案。
- 不要把 WebView/H5 当作主应用实现方式。

## Spec Kit 工作流

复杂功能必须遵循 Spec Kit 流程：

1. `$speckit-constitution`
2. `$speckit-specify`
3. `$speckit-clarify`
4. `$speckit-plan`
5. `$speckit-tasks`
6. `$speckit-analyze`
7. `$speckit-implement`

禁止在没有读完 specification、plan、tasks 的情况下直接开始编码。

## HarmonyOS 技术约束

优先采用：

- HarmonyOS 6.1 原生工程结构
- ArkTS
- ArkUI 声明式 UI
- Stage Model / UIAbility
- RDB Store 作为核心结构化本地数据库
- Preferences 保存轻量用户偏好
- Reminder/Notification 能力实现到期提醒
- Photo Picker / Camera Picker 记录物品照片
- Service Widget/Form Kit 展示“即将过期”“快速新增”“快速搜索”等高频入口
- 多设备自适应布局，至少考虑手机与平板
- 必要时使用 Scan Kit 或系统扫码能力支持条码/二维码入库
- Share Kit 或系统分享能力支持导入/导出或分享物品清单

禁止：

- 未确认 SDK 支持前编造 HarmonyOS API、包名、权限名或配置项。
- 未确认用户同意前引入云同步、账号登录、广告、第三方统计 SDK。
- 未确认前把照片、物品名称、位置、保质期上传到服务端。
- 为了提醒功能滥用后台常驻任务。

## 隐私与数据原则

ItemTrace 默认是 **本地优先、隐私优先** 的 App。

- MVP 不需要登录。
- MVP 不需要后端服务。
- 所有物品、位置、图片索引、提醒规则默认保存在本地。
- 如后续加入云同步，必须作为单独功能规格重新设计。
- 敏感信息包括：物品清单、家庭空间位置、药品/食品信息、照片、备注。
- 数据删除必须有确认，不允许误删。
- 重要数据结构变更必须包含迁移方案。

## 业务范围

核心对象：

- 物品 Item
- 位置 Location
- 分类 Category
- 批次 Batch
- 提醒 Reminder
- 图片 Asset
- 标签 Tag
- 操作记录 TraceEvent

MVP 必须支持：

- 新增物品
- 编辑物品
- 删除/归档物品
- 设置位置
- 设置数量和单位
- 设置保质期或到期日
- 设置提前提醒
- 搜索物品
- 按位置/分类/状态筛选
- 查看即将过期物品
- 添加注意事项
- 添加物品照片

## 体验原则

- 新增物品必须足够快，允许先填最少字段后补充。
- “在哪里”比“分类是什么”更重要，位置路径必须在列表中清晰展示。
- 首页必须优先展示：快速搜索、最近添加、即将过期、低库存/待处理。
- 到期提醒不能只依赖 App 内页面，必须尽量使用系统提醒/通知能力。
- 空状态必须引导用户快速创建第一个位置和物品。
- 对老人或家庭场景友好：字体清晰、信息层级简单、操作不绕。

## 分阶段交付原则

每个阶段都必须可运行、可验证。

### 阶段 1：本地核心闭环

- ArkUI 页面骨架
- RDB 数据模型
- 位置管理
- 物品 CRUD
- 搜索/筛选
- 到期日计算
- 简单提醒能力
- 基础测试或可验证步骤

### 阶段 2：HarmonyOS 特性增强

- 拍照/相册选图
- 系统提醒/通知完善
- 服务卡片
- 多设备自适应布局
- 扫码录入
- 分享/导出

### 阶段 3：高级管理能力

- 批次管理
- 低库存提醒
- 借出/归还记录
- 统计视图
- 数据备份/恢复
- 可选云同步设计，但不默认实现

## 开发执行规则

- 修改前先阅读相关文件。
- 每次只实现当前任务，不擅自扩大范围。
- 每次新增模型必须同步更新数据模型文档。
- 每次新增页面必须说明路由入口和状态管理方式。
- 每次新增权限必须说明用途、触发时机、拒绝后的降级体验。
- 每次使用 HarmonyOS Kit 前必须确认当前 SDK 可用。
- 完成后必须运行可用的构建、检查或测试命令。
- 构建失败不能忽略，必须修复或明确说明原因。

## Codex 特别要求

- 不要在没有用户要求时生成大量无关样板代码。
- 不要用伪代码冒充已实现代码。
- 不要编造 DevEco Studio、ohpm、hvigor 命令执行结果。
- 不要删除用户已有文件，除非任务明确要求。
- 如果项目结构与本文件描述不一致，先说明差异，再提出最小修改方案。
