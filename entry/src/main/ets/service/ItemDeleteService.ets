import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result } from '../common/Result';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class ItemDeleteService {
  private readonly repository: ItemRepositoryPort;

  constructor(repository: ItemRepositoryPort) {
    this.repository = repository;
  }

  async delete(itemId: string, confirmed: boolean): Promise<Result<void>> {
    if (!confirmed) {
      return failure<void>(new AppError(AppErrorCode.VALIDATION, '请确认删除操作'));
    }
    return this.repository.deleteConfirmed(itemId);
  }
}
