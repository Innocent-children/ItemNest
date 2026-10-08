import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { Item } from '../../model/Item';
import { ItemQuery } from '../../model/ItemQuery';
import { ItemDao } from '../dao/ItemDao';

export interface ItemRepositoryPort {
  create(item: Item): Promise<Result<Item>>;
  getById(itemId: string): Promise<Result<Item | undefined>>;
  update(item: Item, singleBatchId?: string, rememberLocation?: boolean): Promise<Result<Item>>;
  updateDetails?(item: Item): Promise<Result<Item>>;
  deleteConfirmed(itemId: string): Promise<Result<void>>;
  listAll(): Promise<Result<Item[]>>;
  list(query: ItemQuery): Promise<Result<Item[]>>;
  listRecent(limit: number): Promise<Result<Item[]>>;
}

export class ItemRepository implements ItemRepositoryPort {
  private readonly itemDao: ItemDao;

  constructor(itemDao: ItemDao) {
    this.itemDao = itemDao;
  }

  async create(item: Item): Promise<Result<Item>> {
    try {
      await this.itemDao.create(item);
      return success(item);
    } catch (error) {
      return failure<Item>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存物品失败，请重试'));
    }
  }

  async getById(itemId: string): Promise<Result<Item | undefined>> {
    try {
      return success(await this.itemDao.findById(itemId));
    } catch (error) {
      return failure<Item | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取物品失败，请重试'));
    }
  }

  async update(item: Item, singleBatchId?: string, rememberLocation: boolean = false): Promise<Result<Item>> {
    try {
      const updated = await this.itemDao.update(item, singleBatchId, rememberLocation);
      if (!updated) {
        return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
      }
      try {
        const saved = await this.itemDao.findById(item.id);
        if (saved === undefined) {
          return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品已保存，但当前记录已不存在，请返回物品列表'));
        }
        return success(saved);
      } catch (_) {
        return failure<Item>(new AppError(AppErrorCode.DATABASE_READ, '物品已保存，暂时无法刷新详情，请重新加载'));
      }
    } catch (error) {
      return failure<Item>(toAppError(error, AppErrorCode.DATABASE_WRITE, '修改物品失败，请重试'));
    }
  }

  async deleteConfirmed(itemId: string): Promise<Result<void>> {
    try {
      const deleted = await this.itemDao.deleteById(itemId);
      if (!deleted) {
        return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
      }
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '删除物品失败，请重试'));
    }
  }

  async updateDetails(item: Item): Promise<Result<Item>> {
    try {
      if (!await this.itemDao.updateDetails(item)) { return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除')); }
      const saved = await this.itemDao.findById(item.id);
      if (saved === undefined) { return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品已保存，但当前记录已不存在')); }
      return success(saved);
    } catch (error) { return failure<Item>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存物品资料失败，请重试')); }
  }

  async listAll(): Promise<Result<Item[]>> {
    try {
      return success(await this.itemDao.findAll());
    } catch (error) {
      return failure<Item[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取物品列表失败，请重试'));
    }
  }

  async list(query: ItemQuery): Promise<Result<Item[]>> {
    try {
      return success(await this.itemDao.findByQuery(query));
    } catch (error) {
      return failure<Item[]>(toAppError(error, AppErrorCode.DATABASE_READ, '查询物品失败，请重试'));
    }
  }

  async listRecent(limit: number): Promise<Result<Item[]>> {
    try {
      return success(await this.itemDao.findRecent(limit));
    } catch (error) {
      return failure<Item[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取物品列表失败，请重试'));
    }
  }
}
