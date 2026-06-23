import { failure, Result, success } from '../../../main/ets/common/Result';
import { AppError, AppErrorCode } from '../../../main/ets/common/AppError';
import { Item } from '../../../main/ets/model/Item';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { ItemRepositoryPort } from '../../../main/ets/data/repository/ItemRepository';

export class FakeItemRepository implements ItemRepositoryPort {
  items: Item[] = [];
  failNextOperation: boolean = false;
  listRecentCallCount: number = 0;

  async create(item: Item): Promise<Result<Item>> {
    if (this.consumeFailure()) {
      return failure<Item>(new AppError(AppErrorCode.DATABASE_WRITE, '保存物品失败，请重试'));
    }
    this.items.push(item);
    return success(item);
  }

  async getById(itemId: string): Promise<Result<Item | undefined>> {
    if (this.consumeFailure()) {
      return failure<Item | undefined>(new AppError(AppErrorCode.DATABASE_READ, '读取物品失败，请重试'));
    }
    return success(this.items.find((item: Item) => item.id === itemId));
  }

  async update(item: Item): Promise<Result<Item>> {
    if (this.consumeFailure()) {
      return failure<Item>(new AppError(AppErrorCode.DATABASE_WRITE, '修改物品失败，请重试'));
    }
    const index = this.items.findIndex((current: Item) => current.id === item.id);
    if (index < 0) {
      return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    this.items[index] = item;
    return success(item);
  }

  async deleteConfirmed(itemId: string): Promise<Result<void>> {
    if (this.consumeFailure()) {
      return failure<void>(new AppError(AppErrorCode.DATABASE_WRITE, '删除物品失败，请重试'));
    }
    const index = this.items.findIndex((item: Item) => item.id === itemId);
    if (index < 0) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    this.items.splice(index, 1);
    return success<void>(undefined);
  }

  async listAll(): Promise<Result<Item[]>> {
    if (this.consumeFailure()) {
      return failure<Item[]>(new AppError(AppErrorCode.DATABASE_READ, '读取物品列表失败，请重试'));
    }
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

  private consumeFailure(): boolean {
    const shouldFail = this.failNextOperation;
    this.failNextOperation = false;
    return shouldFail;
  }
}
