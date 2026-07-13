import { describe, it, expect } from '@ohos/hypium';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
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
    expirationDate: index < 12 ? '2026-06-20' : undefined,
    photoState: PhotoState.NONE,
    createdAt: index,
    updatedAt: index
  };
}

export default function itemSearchAndSummaryTest() {
  describe('ItemSearchService and HomeSummaryService', () => {
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

    it('首页摘要限制十条并识别临期和待补货', 0, async () => {
      const repository = new FakeItemRepository();
      for (let index = 0; index < 50; index++) {
        repository.items.push(createItem(index));
      }
      const summary = await new HomeSummaryService(repository, new ExpiryService())
        .getSummary(new Date(2026, 5, 20));
      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(summary.getData().recentItems.length).assertEqual(10);
        expect(summary.getData().dueSoonItems.length).assertEqual(10);
        expect(summary.getData().outOfStockItems.length).assertEqual(10);
        expect(summary.getData().dueSoonCount).assertEqual(12);
        expect(summary.getData().outOfStockCount).assertEqual(12);
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

      const summary = await new HomeSummaryService(repository, new ExpiryService())
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
