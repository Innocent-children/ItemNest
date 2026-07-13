import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result } from '../common/Result';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { ReminderService } from './ReminderService';
import { PhotoService } from './PhotoService';

export class ItemDeleteService {
  private readonly repository: ItemRepositoryPort;
  private readonly reminders?: ReminderService;
  private readonly photos?: PhotoService;

  constructor(repository: ItemRepositoryPort, reminders?: ReminderService, photos?: PhotoService) {
    this.repository = repository;
    this.reminders = reminders;
    this.photos = photos;
  }

  async delete(itemId: string, confirmed: boolean): Promise<Result<void>> {
    if (!confirmed) {
      return failure<void>(new AppError(AppErrorCode.VALIDATION, '请确认删除操作'));
    }
    const itemResult = await this.repository.getById(itemId);
    if (!itemResult.ok) {
      return failure<void>(itemResult.getError());
    }
    const item = itemResult.getData();
    if (item === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    let localPhotoPath: string | undefined = undefined;
    if (this.photos !== undefined) {
      const localPathResult = await this.photos.getLocalPath(item);
      if (localPathResult.ok) {
        localPhotoPath = localPathResult.getData();
      }
    }
    if (this.reminders !== undefined) {
      const cancelled = await this.reminders.cancelForItem(itemId);
      if (!cancelled.ok) {
        return failure<void>(cancelled.getError());
      }
    }
    const deleted = await this.repository.deleteConfirmed(itemId);
    if (!deleted.ok && this.reminders !== undefined) {
      await this.reminders.reconcile(item);
    }
    if (deleted.ok && this.photos !== undefined) {
      await this.photos.cleanupAfterItemDeleted(item, localPhotoPath);
    }
    return deleted;
  }
}
