# Contract: 应用内命令、查询与撤销

本契约定义未来 ArkTS 模块间行为，不是已经存在的类或实现。全部入口共用，不提供网络 API。

## 写命令

`CommandService.execute(command, operationId, expectedVersions)` 的调用方是已确认的应用内面板，或唯一白名单互动卡片操作。`operationId` 标识一次用户操作，不由物品 ID 代替。

| 命令 | 关键入参 | 前置条件和结果 |
| --- | --- | --- |
| CreateItem | 名称、类型、单位、可空位置/日期、数量和选填资料 | 名称唯一必填；数量默认 1；数量为零时可无份；返回物品 ID 和回执 |
| EditItemFields | itemId、明确字段补丁 | 只写声明字段，禁止隐式回写数量/位置/日期 |
| AddStock | itemId、数量、位置、到期日 | 消耗品可用；按 R4 合并；同次确认只写一次 |
| Consume / ConsumeOne | itemId、来源份、数量 | 仅消耗品；不能超过该份在手；自动来源按 DM-01 |
| DiscardExpired | itemId、portionId | 仅清空已过期消耗品该份在手，借出保持不变 |
| MoveStock | itemId、portionId、目标位置、移动数量 | 默认整份在手；少于整份时拆分；不移动借出中的数量 |
| AdjustOnHand | portionId、实际在手 | 保存为实际在手+未还，不能输入负数 |
| Lend | itemId、portionId、person、数量、dueDate、note | 一笔一个来源份，候选默认在手最多的份；数量不超过在手 |
| ReturnLoan | loanId、数量 | 默认该笔全部未还；部分归还不超过未还 |
| CorrectLoan / CorrectReturn | 记录 ID、明确补丁 | 校验当前相关记录，未还和在手都不为负 |
| VoidLoan / VoidReturn | 记录 ID | 只逻辑撤销；借出连带归还的范围写入回执 |
| DeleteItem / RestoreItem | itemId | 未还时删除需确认；软删/恢复后对账索引和提醒 |
| PurgeItem | itemId | 明确永久删除确认，数据库先提交，文件后清理 |
| ChangePlaceTree | 操作类型、来源与目标 | 改名、移动、删除和合并先计算最终树，再更新份引用、标签和路径 |
| BatchCommand | 具体操作、目标 ID 列表 | 需求文档定义的批量移动、分类、删除、购物补货在一个事务完成；分享只读 |

成功返回结果摘要、提交数据版本与回执 ID；失败返回可识别的业务原因。没有成功提交不得显示“已完成”。幂等重复调用返回该次操作的结果，不能重复写库存或生成多条动态。

## 撤销

`UndoService.undo(receiptId)` 从回执加载前后实体、版本和引用变化，在事务内核对。全部符合才一次恢复并标记原动态已撤销；拒绝时当前数据不变。恢复旧资料不覆盖新库存，合并撤销不丢来源关系。永久删除和覆盖恢复不提供普通提示条撤销；覆盖恢复通过安全备份另行恢复。

## 查询

- `QueryService.search(query, filters, sort)`：按空格拆词，每词须命中；名称完全相同/开头/包含、别名、名称拼音、位置或分类、条码、备注分别为 1–8 分，累加越低越前，相同按最近业务活动，再以 ID 稳定排序。拼音命中仍可显示中文位置名称。
- `QueryService.getItem(itemId)`：排除软删除；计算共有、每份在手、借出、最早到期和最近五条动态。零份物品仍能读取。
- `QueryService.getPlace(placeId, includeDescendants)`：默认含下级，按物品 ID 去重计件；份数量与物品件数分开。
- `QueryService.getTodo(localDate)`：一次生成五组及三组角标，同一快照供首页、待办、卡片、智能体使用。
- `QueryService.getSharePreview(kind, options)`：先产出可审阅内容，用户决定位置、备注、借用人和照片等字段后才交系统渠道。

## 业务失败与并发

可识别原因包括输入不合法、在手不足、未还不足、后续已改动、目标不存在/已删除、树结构冲突和功能不允许。页面用一句中文说明原因和下一步，不把内部错误码显示成产品状态。

应用与扩展必须符合 `plan.md` 的跨入口串行/互斥约束。设备验证同时点击页面和 W6、重复投递同 operationId、归还与用掉交错、用旧回执撤销，结果不能超扣或重复。
