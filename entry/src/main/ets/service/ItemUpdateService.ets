import { AppError, AppErrorCode } from '../common/AppError';
import { ItemValidator, ValidatedItemDraft } from '../common/ItemValidator';
import { failure, Result } from '../common/Result';
import { Item, ItemDetailsDraft, ItemDraft } from '../model/Item';
import { BatchRepositoryPort } from '../data/repository/BatchRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class ItemUpdateService {
  private readonly repository: ItemRepositoryPort;
  private readonly validator: ItemValidator;
  private readonly clock: () => number;
  private readonly batches?: BatchRepositoryPort;

  constructor(repository: ItemRepositoryPort, validator: ItemValidator, clock: () => number = () => Date.now(),
    batches?: BatchRepositoryPort) {
    this.repository = repository;
    this.validator = validator;
    this.clock = clock;
    this.batches = batches;
  }

  async update(itemId: string, draft: ItemDraft): Promise<Result<Item>> {
    const validated = this.validator.validate(draft);
    if (!validated.ok) {
      return failure<Item>(validated.getError());
    }
    const existingResult = await this.repository.getById(itemId);
    if (!existingResult.ok) {
      return failure<Item>(existingResult.getError());
    }
    if (existingResult.getData() === undefined) {
      return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const existing = existingResult.getData() as Item;
    let singleBatchId: string | undefined = undefined;
    if (this.batches !== undefined) {
      const batchResult = await this.batches.listByItemId(itemId);
      if (!batchResult.ok) {
        return failure<Item>(batchResult.getError());
      }
      const data = validated.getData();
      const aggregateChanged = data.quantity !== existing.quantity || data.expirationDate !== existing.expirationDate;
      if (batchResult.getData().length === 1) {
        singleBatchId = batchResult.getData()[0].id;
      } else if (batchResult.getData().length > 1 && aggregateChanged) {
        return failure<Item>(new AppError(
          AppErrorCode.VALIDATION,
          '物品分为多个批次，请到库存明细选择要修改的数量和到期日'
        ));
      }
    }
    return this.repository.update(this.buildUpdatedItem(existing, validated.getData()), singleBatchId, true);
  }

  /**
   * 资料编辑只保存资料字段，读取期间发生的消耗、补入和换位置由各自的库存操作负责。
   */
  async updateDetails(itemId: string, draft: ItemDetailsDraft): Promise<Result<Item>> {
    const result = await this.repository.getById(itemId);
    if (!result.ok) { return failure<Item>(result.getError()); }
    const item = result.getData();
    if (item === undefined) { return failure<Item>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除')); }
    const validated = this.validator.validate({ name: draft.name, unit: draft.unit ?? item.unit,
      category: draft.category, reminderDays: draft.reminderDays, notes: draft.notes, barcode: draft.barcode,
      quantity: item.quantity, locationPath: item.locationPath, expirationDate: item.expirationDate });
    if (!validated.ok) { return failure<Item>(validated.getError()); }
    if (this.repository.updateDetails === undefined) {
      return failure<Item>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '当前无法保存物品资料，请重新打开应用后重试'));
    }
    return this.repository.updateDetails(this.buildUpdatedItem(item, validated.getData()));
  }

  private buildUpdatedItem(existing: Item, data: ValidatedItemDraft): Item {
    return {
      id: existing.id,
      name: data.name,
      quantity: data.quantity,
      unit: data.unit,
      locationPath: data.locationPath,
      category: data.category,
      expirationDate: data.expirationDate,
      reminderDays: data.reminderDays,
      notes: data.notes,
      barcode: data.barcode,
      photoState: existing.photoState,
      photoLocalId: existing.photoLocalId,
      createdAt: existing.createdAt,
      updatedAt: this.clock()
    };
  }
}
