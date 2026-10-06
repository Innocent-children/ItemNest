# ItemNest 源码职责

- common：结果、错误、输入与备份校验、页面数据变更通知。
- model：物品、批次、位置、标签、借还、提醒和系统入口的数据结构。
- data/rdb：数据库打开、事务、版本迁移、表结构和数据约束。
- data/dao、data/repository：持久化、查询与行映射；业务规则由 service 决定。
- service：物品与批次操作、借还、提醒、照片、备份恢复，以及系统能力协调。
- service/adapter：扫码、照片选择、OCR、NFC、系统提醒等平台调用。
- insightintents：意图声明及参数转换；查询调用已有服务，修改操作打开应用内确认页。
- navigation：内部导航、外部链接解析、系统入口与业务页面之间的路由。
- forms：三种桌面卡片及卡片生命周期。数据由 FormSnapshotProvider 提供。
- pages、components：界面与交互，通过服务访问业务数据，不直接操作 SQL。

最低系统为 HarmonyOS API 26。系统入口使用相同的物品、批次和借还服务，避免出现单独的系统库存。收纳标签以位置 ID 关联，并随物品备份一起恢复。小艺和实况窗的平台开通、调试与验证要求见 docs/HarmonyOS集成说明.md。
