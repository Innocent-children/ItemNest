# 实施计划：[功能名称]

**分支**：`[###-feature-name]` | **日期**：[日期] | **规格**：[spec.md 链接]

**输入**：`/specs/[###-feature-name]/spec.md` 中经确认的功能规格。

**说明**：本模板由 `/speckit-plan` 填写。所有设计结论与待查证项必须使用中文。

## 摘要

[从功能规格提炼目标、用户价值、范围边界和拟采用的技术路径。]

## 技术上下文

**语言/版本**：ArkTS；HarmonyOS SDK [从 `build-profile.json5` 读取]

**主要依赖**：ArkUI、Stage Model / UIAbility；[列出已验证的 Kit 与版本，未验证项标为“需要查证”]

**存储**：RDB Store（结构化业务数据）；Preferences（轻量用户偏好）；[迁移方案或不适用]

**测试与验证**：[当前可用的单元测试、ohosTest、构建、静态检查和手工验收命令]

**目标设备**：[从 `module.json5` 读取；明确手机、折叠屏、平板的适配范围]

**项目类型**：HarmonyOS 原生移动应用，Stage Model

**性能与体验目标**：[可衡量的首屏、搜索、列表交互或数据规模目标]

**约束**：本地优先；不得接入未获批准的账号、后端、云同步、广告或第三方统计；不得编造 API。

**范围**：[本阶段用户故事、明确不做的内容，以及与阶段 1/2/3 的对应关系]

## 宪章检查

*门禁：Phase 0 调研前必须全部通过；Phase 1 设计完成后必须再次检查。未通过项必须填入复杂度跟踪。*

- [ ] 已读取并记录当前 `build-profile.json5`、`oh-package.json5`、`entry/oh-package.json5`、
  `entry/src/main/module.json5` 与实际 `entry` 模块结构。
- [ ] 技术实现使用 ArkTS、ArkUI 与 Stage Model；未以 Android/iOS/WebView/H5 替代原生主流程。
- [ ] 数据存储边界已定义：结构化数据使用 RDB Store，轻量偏好使用 Preferences，并已说明迁移策略。
- [ ] 本地优先与隐私边界已定义；没有未经单独批准的账号、后端、云同步、广告或第三方统计。
- [ ] 每个系统能力均已核验 SDK、依赖、权限和失败降级；未核验能力已标记“需要查证”并隔离。
- [ ] 页面路由、状态管理、服务边界、提醒生命周期与权限触发/拒绝体验已定义。
- [ ] 响应式布局覆盖目标设备；新增物品、位置路径、搜索、空状态和提醒信息满足体验原则。
- [ ] 任务拆分支持按阶段独立构建、测试或演示，并列出实际验证命令。

## 项目结构

### 功能文档

```text
specs/[###-feature-name]/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### 源码

```text
AppScope/
entry/
├── src/main/ets/
│   ├── entryability/
│   ├── pages/
│   ├── components/       # 按功能需要创建
│   ├── models/           # 按功能需要创建
│   ├── services/         # 按功能需要创建
│   └── repositories/     # 按功能需要创建
├── src/main/resources/
├── src/test/
└── src/ohosTest/
```

**结构决策**：[说明实际修改的目录、模块归属，以及为什么未新增或新增其他模块。]

## 复杂度跟踪

> 仅在宪章检查存在例外时填写；每项例外必须获得明确批准。

| 例外 | 必要原因 | 拒绝的更简单方案 | 隐私、兼容性与验证影响 |
|---|---|---|---|
| [例如：新增可替换的扫码适配层] | [具体业务原因] | [为什么不能只用手工录入] | [权限、SDK 核验和降级验证] |
