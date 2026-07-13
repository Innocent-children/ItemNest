import { AppError, AppErrorCode } from '../common/AppError';
import { ItemValidator } from '../common/ItemValidator';
import { failure, Result, success } from '../common/Result';
import { Batch, BatchDraft, createBatchId } from '../model/Batch';
import { isItemUnit, ItemUnit } from '../model/Item';
import { normalizeLocationPath } from '../model/LocationPath';
import { BatchRepositoryPort } from '../data/repository/BatchRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class BatchService {
  private readonly batches: BatchRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;
  private readonly itemValidator: ItemValidator = new ItemValidator();
  private deleteQueue: Promise<void> = Promise.resolve();

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
    const item = itemResult.getData();
    if (item === undefined) {
      return failure<Batch>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const validated = this.validateDraft(draft, item.unit);
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
    return this.batches.create(batch);
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
    const itemResult = await this.items.getById(existing.itemId);
    if (!itemResult.ok) {
      return failure<Batch>(itemResult.getError());
    }
    const item = itemResult.getData();
    if (item === undefined) {
      return failure<Batch>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const validated = this.validateDraft({
      itemId: existing.itemId,
      quantity: draft.quantity,
      unit: draft.unit,
      expirationDate: draft.expirationDate,
      locationPath: draft.locationPath,
      notes: draft.notes
    }, item.unit);
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
    return this.batches.update(batch);
  }

  async delete(batchId: string): Promise<Result<void>> {
    return this.runExclusiveDelete(() => this.deleteInternal(batchId));
  }

  private async deleteInternal(batchId: string): Promise<Result<void>> {
    const existingResult = await this.batches.getById(batchId);
    if (!existingResult.ok) {
      return failure<void>(existingResult.getError());
    }
    const existing = existingResult.getData();
    if (existing === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '批次不存在或已删除'));
    }
    const itemBatchesResult = await this.batches.listByItemId(existing.itemId);
    if (!itemBatchesResult.ok) {
      return failure<void>(itemBatchesResult.getError());
    }
    if (itemBatchesResult.getData().length <= 1) {
      return failure<void>(new AppError(
        AppErrorCode.VALIDATION,
        '至少保留一个批次；如需清空库存，请将最后一个批次数量改为 0'
      ));
    }
    return this.batches.deleteConfirmed(batchId);
  }

  private async runExclusiveDelete(operation: () => Promise<Result<void>>): Promise<Result<void>> {
    const previous = this.deleteQueue;
    let release: () => void = () => {};
    this.deleteQueue = new Promise<void>((resolve: () => void) => {
      release = resolve;
    });
    await previous;
    try {
      return await operation();
    } finally {
      release();
    }
  }

  private validateDraft(draft: BatchDraft, expectedUnit: ItemUnit): Result<Batch> {
    const itemId = draft.itemId.trim();
    if (itemId.length === 0) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '缺少物品标识'));
    }
    const quantity = draft.quantity ?? 1;
    const scaled = quantity * 100;
    if (!Number.isFinite(quantity) || quantity < 0 || Math.abs(Math.round(scaled) - scaled) >= 1e-9) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '批次数量必须是最多两位小数的非负数'));
    }
    const unit = draft.unit ?? expectedUnit;
    if (!isItemUnit(unit)) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, '请选择有效的批次单位'));
    }
    if (unit !== expectedUnit) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, `批次单位必须与物品单位一致（${expectedUnit}）`));
    }
    const expiration = draft.expirationDate?.trim() ?? '';
    const expirationResult = this.itemValidator.validateExpirationDate(expiration);
    if (!expirationResult.ok) {
      return failure<Batch>(new AppError(AppErrorCode.VALIDATION, `批次${expirationResult.getError().message}`));
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
      expirationDate: expirationResult.getData(),
      locationPath: normalizeLocationPath(draft.locationPath),
      notes: notes.length === 0 ? undefined : notes,
      createdAt: 0,
      updatedAt: 0
    };
    return success(validatedBatch);
  }
}
