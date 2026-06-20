import { AppError } from '../../common/AppError';
import { Result } from '../../common/Result';
import { BatchDao } from '../dao/BatchDao';
import { Batch, BatchDraft, BatchSummary } from '../../model/Batch';
import { ItemDao } from '../dao/ItemDao';

export class BatchRepository {
  constructor(private batchDao: BatchDao, private itemDao: ItemDao) { }

  create(draft: BatchDraft, now: number): Result<Batch> {
    const itemResult = this.itemDao.getById(draft.itemId);
    if (!itemResult.ok) {
      return Result.failure(itemResult.error!);
    }
    const item = itemResult.getData();
    if (item === null) {
      return Result.failure(AppError.of('ITEM_NOT_FOUND', '物品不存在'));
    }
    const id = atch_\_\;
    const batch = new Batch({
      id,
      itemId: draft.itemId,
      quantity: draft.quantity,
      unit: draft.unit ?? '个',
      expirationDate: draft.expirationDate ?? null,
      locationPath: draft.locationPath ?? null,
      notes: draft.notes ?? null,
      createdAt: now,
      updatedAt: now
    });
    const insertResult = this.batchDao.insert(batch);
    if (!insertResult.ok) {
      return Result.failure(insertResult.error!);
    }
    return Result.success(batch);
  }

  getById(id: string): Result<Batch | null> {
    return this.batchDao.getById(id);
  }

  listByItemId(itemId: string): Result<Batch[]> {
    return this.batchDao.listByItemId(itemId);
  }

  update(id: string, draft: BatchDraft, now: number): Result<void> {
    const existingResult = this.batchDao.getById(id);
    if (!existingResult.ok) {
      return Result.failure(existingResult.error!);
    }
    const existing = existingResult.getData();
    if (existing === null) {
      return Result.failure(AppError.of('BATCH_NOT_FOUND', '批次不存在'));
    }
    existing.quantity = draft.quantity;
    existing.unit = draft.unit ?? existing.unit;
    existing.expirationDate = draft.expirationDate !== undefined ? draft.expirationDate : existing.expirationDate;
    existing.locationPath = draft.locationPath !== undefined ? draft.locationPath : existing.locationPath;
    existing.notes = draft.notes !== undefined ? draft.notes : existing.notes;
    existing.updatedAt = now;
    return this.batchDao.update(existing);
  }

  deleteById(id: string): Result<void> {
    return this.batchDao.deleteById(id);
  }
}
