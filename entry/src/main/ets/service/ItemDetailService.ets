import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { Item } from '../model/Item';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class ItemDetailService {
  private readonly repository: ItemRepositoryPort;

  constructor(repository: ItemRepositoryPort) {
    this.repository = repository;
  }

  async getDetail(itemId: string): Promise<Result<Item>> {
    const result = await this.repository.getById(itemId);
    if (!result.ok) {
      return failure<Item>(result.getError());
    }
    if (result.getData() === undefined) {
      return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    return success(result.getData() as Item);
  }
}
