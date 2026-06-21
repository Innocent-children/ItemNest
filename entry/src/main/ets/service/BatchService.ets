import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { Batch, BatchDraft, createBatchId } from '../model/Batch';
import { Item, isItemUnit, ItemUnit } from '../model/Item';
import { normalizeLocationPath } from '../model/LocationPath';
import { BatchRepositoryPort } from '../data/repository/BatchRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class BatchService {
  private readonly batches: BatchRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;

  constructor(batches: BatchRepositoryPort, items: ItemRepositoryPort, clock: () => number = () => Date.now()) {
    this.batches = batches;
    this.items = items;
    this.clock = clock;
  }

  async listByItemId(itemId: string): Promise<Result<Batch[]>> {
    return this.batches.listByItemId(itemId);
  }

  async create(draft: BatchDraft): Promise<Result<Batch>> {
    const itemResult = await this.items.getById(draft.itemId);
    if (!itemResult.ok) {
      return failure<Batch>(itemResult.getError());
    }
    if (itemResult.getData() === undefined) {
      return failure<Batch>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const validated = this.validateDraft(draft);
    if (!validated.ok) {
      return failure<Batch>(validated.getError());
    }
    const now = this.clock();
    const data = validated.getData();
    const batch: Batch = {
      id: createBatchId(this.clock),
      itemId: data.itemId,
      quantity: data.quantity,
      unit: data.unit,
      expirationDate: data.expirationDate,
      locationPath: data.locationPath,
      notes: data.notes,
      createdAt: now,
      updatedAt: now
    };
    const created = await this.batches.create(batch);
    if (!created.ok) {
      return created;
    }
    const refreshed = await this.refreshItemRollup(batch.itemId);
    if (!refreshed.ok) {
      return failure<Batch>(refreshed.getError());
    }
    return created;
  }

  async update(batchId: string, draft: BatchDraft): Promise<Result<Batch>> {
    const existingResult = await this.batches.getById(batchId);
    if (!existingResult.ok) {
      return failure<Batch>(existingResult.getError());
    }
    const existing = existingResult.getData();
    if (existing === undefined) {
      return failure<Batch>(new AppError(AppErrorCode.NOT_FOUND, '批次不存在或已删除'));
    }
    const validated = this.validateDraft({
      itemId: existing.itemId,
      quantity: draft.quantity,
      unit: draft.unit,
      expirationDate: draft.expirationDate,
      locationPath: draft.locationPath,
      notes: draft.notes
    });
    if (!validated.ok) {
      return failure<Batch>(validated.getError());
    }
    const data = validated.getData();
    const batch: Batch = {
      id: existing.id,
      itemId: existing.itemId,
      quantity: data.quantity,
      unit: data.unit,
      expirationDate: data.expirationDate,
      locationPath: data.locationPath,
      notes: data.notes,
      createdAt: existing.createdAt,
      updatedAt: this.clock()
    };
    const updated = await this.batches.update(batch);
    if (!updated.ok) {
      return updated;
    }
    const refreshed = await this.refreshItemRollup(batch.itemId);
    if (!refreshed.ok) {
      return failure<Batch>(refreshed.getError());
    }
    return updated;
  }

  async delete(batchId: string): Promise<Result<void>> {
    const existingResult = await this.batches.getById(batchId);
    if (!existingResult.ok) {
      return failure<void>(existingResult.getError());
    }
    const existing = existingResult.getData();
    if (existing === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '批次不存在或已删除'));
    }
    const deleted = await this.batches.deleteConfirmed(batchId);
    if (!deleted.ok) {
      return deleted;
    }
    return this.refreshItemRollup(existing.itemId);
  }

  private async refreshItemRollup(itemId: string): Promise<Result<void>> {
    const itemResult = await this.items.getById(itemId);
    if (!itemResult.ok) {
      return failure<void>(itemResult.getError());
    }
    const item = itemResult.getData();
    if (item === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const batchResult = await this.batches.listByItemId(itemId);
    if (!batchResult.ok) {
      return failure<void>(batchResult.getError());
    }
    const batches = batchResult.getData();
    let quantity = 0;
    let earliestExpiration: string | undefined = undefined;
    for (let index = 0; index < batches.length; index++) {
      quantity += batches[index].quantity;
      const expiration = batches[index].expirationDate;
      if (expiration !== undefined && (earliestExpiration === undefined || expiration < earliestExpiration)) {
        earliestExpiration = expiration;
      }
    }
    const updatedItem: Item = {
      id: item.id,
      name: item.name,
      quantity: Math.round(quantity * 100) / 100,
      unit: item.unit,
      locationPath: item.locationPath,
      category: item.category,
      expirationDate: earliestExpiration,
      reminderDays: item.reminderDays,
      notes: item.notes,
      photoState: item.photoState,
      photoLocalId: item.photoLocalId,
      createdAt: item.createdAt,
      updatedAt: this.clock()
    };
    const updated = await this.items.update(updatedItem);
    if (!updated.ok) {
      return failure<void>(updated.getError());
    }
    return success<void>(undefined);
  }

  private validateDraft(draft: BatchDraft): Result<Batch> {
    const itemId = draft.itemId.trim();
    if (itemId.length === 0) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '缺少物品标识'));
    }
    const quantity = draft.quantity ?? 1;
    const scaled = quantity * 100;
    if (!Number.isFinite(quantity) || quantity < 0 || Math.abs(Math.round(scaled) - scaled) >= 1e-9) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '批次数量必须是最多两位小数的非负数'));
    }
    const unit = draft.unit ?? ItemUnit.PIECE;
    if (!isItemUnit(unit)) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '请选择有效的批次单位'));
    }
    const expiration = draft.expirationDate?.trim() ?? '';
    if (expiration.length > 0 && !/^\d{4}-\d{2}-\d{2}$/.test(expiration)) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '批次到期日期格式应为 YYYY-MM-DD'));
    }
    const notes = draft.notes?.trim() ?? '';
    if (notes.length > 500) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '批次备注不能超过 500 个字符'));
    }
    const validatedBatch: Batch = {
      id: '',
      itemId: itemId,
      quantity: quantity,
      unit: unit,
      expirationDate: expiration.length === 0 ? undefined : expiration,
      locationPath: normalizeLocationPath(draft.locationPath),
      notes: notes.length === 0 ? undefined : notes,
      createdAt: 0,
      updatedAt: 0
    };
    return success(validatedBatch);
  }
}
