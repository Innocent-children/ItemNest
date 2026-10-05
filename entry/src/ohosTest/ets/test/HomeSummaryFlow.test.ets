import { FakeStockThresholdRepository } from '../../../test/ets/test/FakeStockThresholdRepository';
import { describe, it, expect } from '@ohos/hypium';
import { AppError, AppErrorCode } from '../../../main/ets/common/AppError';
import { Result, failure, success } from '../../../main/ets/common/Result';
import { ItemRepositoryPort } from '../../../main/ets/data/repository/ItemRepository';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { ExpiryService } from '../../../main/ets/service/ExpiryService';
import { HomeSummaryService } from '../../../main/ets/service/HomeSummaryService';

class HomeSummaryFakeRepository implements ItemRepositoryPort {
  items: Item[] = [];
  listRecentCallCount: number = 0;

  async create(item: Item): Promise<Result<Item>> {
    this.items.push(item);
    return success(item);
  }

  async getById(itemId: string): Promise<Result<Item | undefined>> {
    return success(this.items.find((item: Item) => item.id === itemId));
  }

  async update(item: Item): Promise<Result<Item>> {
    const index = this.items.findIndex((current: Item) => current.id === item.id);
    if (index < 0) {
      return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    this.items[index] = item;
    return success(item);
  }

  async deleteConfirmed(itemId: string): Promise<Result<void>> {
    const index = this.items.findIndex((item: Item) => item.id === itemId);
    if (index < 0) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    this.items.splice(index, 1);
    return success<void>(undefined);
  }

  async listAll(): Promise<Result<Item[]>> {
    return success(this.items.slice().sort((left: Item, right: Item) => right.createdAt - left.createdAt));
  }

  async list(query: ItemQuery): Promise<Result<Item[]>> {
    const allResult = await this.listAll();
    if (!allResult.ok) {
      return allResult;
    }
    const normalized = query.normalized();
    return success(allResult.getData().filter((item: Item) => {
      const nameMatched = normalized.name.length === 0 || item.name.includes(normalized.name);
      const locationMatched = normalized.locationPath === undefined || item.locationPath === normalized.locationPath;
      const categoryMatched = normalized.category === undefined || item.category === normalized.category;
      return nameMatched && locationMatched && categoryMatched;
    }));
  }

  async listRecent(limit: number): Promise<Result<Item[]>> {
    this.listRecentCallCount += 1;
    const allResult = await this.listAll();
    if (!allResult.ok) {
      return allResult;
    }
    return success(allResult.getData().slice(0, limit));
  }
}

function createSummaryItem(index: number): Item {
  return {
    id: `item-${index}`,
    name: `测试物品${index}`,
    quantity: 1,
    unit: ItemUnit.PIECE,
    locationPath: '客厅 / 收纳箱',
    category: '生活用品',
    photoState: PhotoState.NONE,
    createdAt: index,
    updatedAt: index
  };
}

export default function homeSummaryFlowTest() {
  describe('Home summary flow', () => {
    it('摘要列表限制十条但保留临期和待补货总数', 0, async () => {
      const repository = new HomeSummaryFakeRepository();
      for (let index = 0; index < 12; index++) {
        const item = createSummaryItem(index);
        item.quantity = 0;
        item.expirationDate = '2026-06-20';
        repository.items.push(item);
        const dueItem = createSummaryItem(index + 12);
        dueItem.expirationDate = '2026-06-20';
        repository.items.push(dueItem);
      }

      const summary = await new HomeSummaryService(repository, new ExpiryService(), new FakeStockThresholdRepository())
        .getSummary(new Date(2026, 5, 20));

      expect(summary.ok).assertTrue();
      if (summary.ok) {
        expect(summary.getData().restockItems.length).assertEqual(12);
        expect(summary.getData().dueSoonCount).assertEqual(12);
        expect(summary.getData().restockCount).assertEqual(12);
      }
    });

    it('新增物品后首页最近添加立即包含最新物品', 0, async () => {
      const repository = new HomeSummaryFakeRepository();
      for (let index = 0; index < 10; index++) {
        repository.items.push(createSummaryItem(index));
      }
      const latestItem = createSummaryItem(100);
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
