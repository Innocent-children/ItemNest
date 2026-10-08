import { FakeStockThresholdRepository } from './FakeStockThresholdRepository';
import { describe, it, expect } from '@ohos/hypium';
import { Item, ItemSummary, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { ExpiryService } from '../../../main/ets/service/ExpiryService';
import { HomeSummaryService } from '../../../main/ets/service/HomeSummaryService';
import { ItemListService } from '../../../main/ets/service/ItemListService';
import { ItemSearchService } from '../../../main/ets/service/ItemSearchService';
import { FakeItemRepository } from './FakeItemRepository';

function createItem(index: number): Item {
  return {
    id: `item-${index}`,
    name: index === 49 ? '目标药品' : `测试物品${index}`,
    quantity: index < 12 ? 0 : 1,
    unit: ItemUnit.PIECE,
    locationPath: index === 49 ? '卧室 / 药箱' : '客厅 / 收纳箱',
    category: index === 49 ? '药品' : '生活用品',
    expirationDate: index >= 12 && index < 24 ? '2026-06-20' : undefined,
    photoState: PhotoState.NONE,
    createdAt: index,
    updatedAt: index
  };
}

export default function itemSearchAndSummaryTest() {
  describe('ItemSearchService and HomeSummaryService', () => {
    it('自由查找覆盖有效位置和分类，保留筛选交集及系统名称查询语义', 0, async () => {
      const repository = new FakeItemRepository();
      const item = createItem(100);
      item.name = '护手霜'; item.category = '生活用品'; item.barcode = 'AB123';
      item.locationPath = '已废弃位置'; item.activeLocationPaths = ['客厅 / 收纳格'];
      repository.items.push(item);
      const service = new ItemSearchService(repository, new ItemListService(repository, new ExpiryService()));
      expect((await service.searchEverywhere(new ItemQuery('客厅'))).getData().items.length).assertEqual(1);
      expect((await service.searchEverywhere(new ItemQuery('生活'))).getData().items.length).assertEqual(1);
      expect((await service.searchEverywhere(new ItemQuery('ab123'))).getData().items.length).assertEqual(1);
      expect((await service.searchEverywhere(new ItemQuery('客厅', undefined, '工具'))).getData().items.length).assertEqual(0);
      expect((await service.searchEverywhere(new ItemQuery('已废弃位置'))).getData().items.length).assertEqual(0);
      expect((await service.search(new ItemQuery('客厅'))).getData().items.length).assertEqual(0);
      repository.failNextOperation = true;
      expect((await service.searchEverywhere(new ItemQuery('护手'))).ok).assertFalse();
    });
    it('在 50 条数据中按名称、位置和分类取交集', 0, async () => {
      const repository = new FakeItemRepository();
      for (let index = 0; index < 50; index++) {
        repository.items.push(createItem(index));
      }
      const listService = new ItemListService(repository, new ExpiryService());
      const searchService = new ItemSearchService(repository, listService);
      const result = await searchService.search(new ItemQuery('目标', '卧室 / 药箱', '药品'));
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().items.length).assertEqual(1);
        expect(result.getData().items[0].name).assertEqual('目标药品');
      }
    });

    it('缺货和低库存合并为补货清单并去重，停用阈值不计入', 0, async () => {
      const repository = new FakeItemRepository();
      const empty = createItem(1);
      const low = createItem(100);
      const disabled = createItem(101);
      repository.items.push(empty, low, disabled);
      const thresholds = new FakeStockThresholdRepository();
      thresholds.thresholds.push(
        { itemId: empty.id, threshold: 2, enabled: true, updatedAt: 1 },
        { itemId: low.id, threshold: 2, enabled: true, updatedAt: 1 },
        { itemId: disabled.id, threshold: 2, enabled: false, updatedAt: 1 });
      const summary = (await new HomeSummaryService(repository, new ExpiryService(), thresholds).getSummary()).getData();
      expect(summary.restockCount).assertEqual(2);
      expect(summary.restockItems.length).assertEqual(2);
      expect(summary.restockItems.some((item: ItemSummary) => item.id === low.id)).assertTrue();
    });

    it('最近添加保留十条，完整待处理和补货清单不截断', 0, async () => {
      const repository = new FakeItemRepository();
      for (let index = 0; index < 50; index++) {
        repository.items.push(createItem(index));
      }
      const summary = await new HomeSummaryService(repository, new ExpiryService(), new FakeStockThresholdRepository())
        .getSummary(new Date(2026, 5, 20));
      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(summary.getData().recentItems.length).assertEqual(10);
        expect(summary.getData().restockItems.length).assertEqual(12);
        expect(summary.getData().dueSoonCount).assertEqual(12);
        expect(summary.getData().restockCount).assertEqual(12);
      }
    });

    it('已过期与临期一起待处理，全部列表不被十条预览截断', 0, async () => {
      const repository = new FakeItemRepository();
      for (let index = 0; index < 16; index++) {
        const item = createItem(index + 100);
        item.expirationDate = index === 0 ? '2026-06-01' : '2026-06-22';
        repository.items.push(item);
      }
      const emptyOldItem = createItem(999);
      emptyOldItem.quantity = 0;
      emptyOldItem.expirationDate = '2026-05-01';
      repository.items.push(emptyOldItem);
      const summary = await new HomeSummaryService(repository, new ExpiryService(), new FakeStockThresholdRepository())
        .getSummary(new Date(2026, 5, 20));
      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(summary.getData().dueSoonCount).assertEqual(16);
        expect(summary.getData().expiryAttentionItems.length).assertEqual(16);
        expect(summary.getData().expiryAttentionItems[0].id).assertEqual('item-100');
        expect(summary.getData().restockCount).assertEqual(1);
      }
    });

    it('详情转换和首页摘要均保留有效批次位置', 0, async () => {
      const repository = new FakeItemRepository();
      const item = createItem(100);
      item.activeLocationPaths = ['新药箱', '书房抽屉'];
      repository.items.push(item);
      const listSummary = new ItemListService(repository, new ExpiryService()).toSummary(item);
      expect(listSummary.activeLocationPaths?.join('；')).assertEqual('新药箱；书房抽屉');
      const homeResult = await new HomeSummaryService(repository, new ExpiryService(), new FakeStockThresholdRepository()).getSummary();
      expect(homeResult.ok).assertTrue();
      if (homeResult.ok) {
        expect(homeResult.getData().recentItems[0].activeLocationPaths?.join('；')).assertEqual('新药箱；书房抽屉');
      }
    });

    it('新增物品后首页最近添加立即包含最新物品', 0, async () => {
      const repository = new FakeItemRepository();
      for (let index = 0; index < 10; index++) {
        repository.items.push(createItem(index));
      }
      const latestItem = createItem(100);
      latestItem.name = '刚新增的物品';
      const createResult = await repository.create(latestItem);
      expect(createResult.ok).assertTrue();

      const summary = await new HomeSummaryService(repository, new ExpiryService(), new FakeStockThresholdRepository())
        .getSummary(new Date(2026, 5, 20));

      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(repository.listRecentCallCount).assertEqual(1);
        expect(summary.getData().recentItems.length).assertEqual(10);
        expect(summary.getData().recentItems[0].id).assertEqual('item-100');
        expect(summary.getData().recentItems[0].name).assertEqual('刚新增的物品');
      }
    });
  });
}
