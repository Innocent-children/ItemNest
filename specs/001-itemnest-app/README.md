# 我的家当 · SpecKit 文档入口

已为新项目“我的家当”建立 SpecKit 规划。用户提供了 `docs/` 需求、`AppScope/` 素材包以及项目名、应用名和包名。文档工具为本机 Specify CLI 1.2.5 的 Codex skills 集成。此次仅完成文档和工具配置，没有创建应用工程、编写业务代码、修改素材、构建、安装或开通平台。

用户提供的文档实际有 **119 条原需求：66 条 P0、43 条 P1、10 条 P2**。本套逐条保留并映射为 **154 项未执行任务**。用户为个人开发者，已将企业受限能力集中后置为可选；原 P0 的 SYS-04 不再阻塞首发，核心必需 P0 为 65 条。任务包含工程、业务、规范核对和验证，不能因出现在清单中就视为必做或已完成。当前为可评审的 Draft，等待新的开发指令。

## 阅读顺序

| 文档 | 用途 |
| --- | --- |
| [spec.md](spec.md) | 9 个原故事及文末 US10 企业可选扩展、功能范围、成功标准和已确认产品决定 |
| [plan.md](plan.md) | 技术方案、工程结构、模块调用、阶段与实施门槛 |
| [research.md](research.md) | 当前文件、API 26 SDK、华为官方资料与技术决定 |
| [data-model.md](data-model.md) | 业务字段、数量、借还、历史引用、撤销和恢复边界 |
| [contracts/domain.md](contracts/domain.md) | 应用内命令、查询、业务并发和撤销 |
| [contracts/external-entry.md](contracts/external-entry.md) | 链接、分享、小艺、A2A、卡片和 AI 的输入输出规则 |
| [contracts/backup.md](contracts/backup.md) | 备份格式、校验、文件和数据库提交边界 |
| [platform-readiness.md](platform-readiness.md) | 已提供文件结论、工程缺项、图标/动画与华为能力完善步骤 |
| [requirements-map.md](requirements-map.md) | 全部 119 条需求到故事、任务和验收场景的逐条映射 |
| [tasks.md](tasks.md) | 154 项后续任务；最后 T148–T154 为企业受限能力，可选、默认不执行 |
| [quickstart.md](quickstart.md) | 后续工程建立、构建和 QV-01–10 验收入口；QV-10 仅选做后执行 |
| [open-questions.md](open-questions.md) | 写完文档后集中提出的疑问与 14 条具体建议 |
| [checklists/requirements.md](checklists/requirements.md) | 本次规格质量检查结果与待执行验证 |
| [checklists/platform.md](checklists/platform.md) | 交给评审者的工程/平台要求完整性清单 |

项目记忆写在根 `AGENTS.md`，项目原则在 `.specify/memory/constitution.md`。禁止查看 `2fe89c3c` 及之前的 Git 记录；本次未查看任何 Git 历史。

## 需求输入与规格文档

`docs/product.md` 定义产品与 T1–T15，`docs/request.md` 定义需求和优先级，`docs/data.md` 定义 R1–R40，`docs/experience.md` 定义交互，`docs/design.md` 定义设计目录，`docs/harmonyos.md` 定义平台能力。

用户提供的六份文档、AppScope 文件和素材本次均未修改。新文档集中说明需求描述中的差异：119/120 条、提醒重复频率、普通物品到期操作、卡片刷新时序、系统渠道隐私、份清理历史和恢复提交边界。发生冲突时先核对 `open-questions.md` 与 `research.md`，区分已确认规则和设计建议，不静默覆盖产品需求。

## 已确认的项目与产品决定

1. 这是新项目，以用户指定的名称、包名、需求和素材包为输入，从零创建工程及业务功能。
2. 本地数据原则用于保护用户数据；华为官方系统备份、换机等能力正常接入，不额外增加数据离机确认。
3. 到期通知按 R24 执行一次提醒、同日合并，不在提前窗口内每天重复。
4. 企业受限的小艺意图/系统搜索、意图共享、模型生成式问答和三种实况窗保留完整规划，统一移至规格和任务末尾，可选、默认不执行、不阻塞核心首发。本地查询结果保留；代理提醒和 SYS-06 端 A2A 独立核验，不一并归为企业专属。

真实发行者名称、测试设备和平台接入资料在实施前补充。购物/连续整理实况窗的场景资格、模型和设备支持不能仅凭 SDK 声明视为通过。

## SpecKit 状态与停止点

已完成 constitution、specify、plan、checklist 和 tasks 的文档产出，并完成文档静态核对；用户后续决定通过 clarify 同步到规格、计划、数据模型、契约和任务。

活动特性由本机 `.specify/feature.json` 指向本目录。该指针按官方规则被忽略，其他检出环境需重新选择活动特性，或设置：

```sh
export SPECIFY_FEATURE_DIRECTORY=specs/001-itemnest-app
```

本次停止在文档交付，不调用 `$speckit-implement`、`$speckit-converge` 或自动工作流执行开发。任务清单中的文件路径都是实施目标，不能据此声称相应代码或工程已经存在。

## 最后：企业受限能力的可选范围

入口为 spec.md 文末 US10、plan.md 最后阶段和 tasks.md 最后 T148–T154。SYS-04/SYS-05、AI-09 的模型生成部分、SYS-08 可全部不做；保留原需求编号和行为，未选项目记录“可选未实施”，不当作测试通过。三种实况窗关联的连续记下、购物和备份先交付完整应用内流程。

Intents Kit 和 localChatModel 已确认企业主体限制；localChatModel 还仅支持 PC/2in1，与当前手机/平板范围不符。实况窗推送路径明确需企业账号，本地路径个人正式商用资格尚未核实，因此整项按用户决定后置。选做前按 research.md 与 platform-readiness.md 核对最新资格，不自动新增 PC、网络权限或服务端。
