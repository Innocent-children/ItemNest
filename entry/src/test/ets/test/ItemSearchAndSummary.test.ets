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
    expirationDate: index >= 12 && index < 24 ? '2026-06-20' : undefined,
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

    it('首页摘要限制十条并分别识别有库存临期和待补货', 0, async () => {
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
      const summary = await new HomeSummaryService(repository, new ExpiryService())
        .getSummary(new Date(2026, 5, 20));
      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(summary.getData().dueSoonCount).assertEqual(16);
        expect(summary.getData().dueSoonItems.length).assertEqual(10);
        expect(summary.getData().expiryAttentionItems.length).assertEqual(16);
        expect(summary.getData().expiryAttentionItems[0].id).assertEqual('item-100');
        expect(summary.getData().outOfStockCount).assertEqual(1);
      }
    });

    it('详情转换和首页摘要均保留有效批次位置', 0, async () => {
      const repository = new FakeItemRepository();
      const item = createItem(100);
      item.activeLocationPaths = ['新药箱', '书房抽屉'];
      repository.items.push(item);
      const listSummary = new ItemListService(repository, new ExpiryService()).toSummary(item);
      expect(listSummary.activeLocationPaths?.join('；')).assertEqual('新药箱；书房抽屉');
      const homeResult = await new HomeSummaryService(repository, new ExpiryService()).getSummary();
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
