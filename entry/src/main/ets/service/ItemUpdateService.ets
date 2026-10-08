import { AppError, AppErrorCode } from '../common/AppError';
import { ItemValidator } from '../common/ItemValidator';
import { failure, Result } from '../common/Result';
import { Item, ItemDraft } from '../model/Item';
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
    const updatedItem: Item = {
      id: existing.id,
      name: validated.getData().name,
      quantity: validated.getData().quantity,
      unit: validated.getData().unit,
      locationPath: validated.getData().locationPath,
      category: validated.getData().category,
      expirationDate: validated.getData().expirationDate,
      reminderDays: validated.getData().reminderDays,
      notes: validated.getData().notes,
      barcode: validated.getData().barcode,
      photoState: existing.photoState,
      photoLocalId: existing.photoLocalId,
      createdAt: existing.createdAt,
      updatedAt: this.clock()
    };
    return this.repository.update(updatedItem, singleBatchId, true);
  }
}
