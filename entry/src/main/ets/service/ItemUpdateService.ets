import { AppError, AppErrorCode } from '../common/AppError';
import { ItemValidator } from '../common/ItemValidator';
import { failure, Result } from '../common/Result';
import { Item, ItemDraft } from '../model/Item';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class ItemUpdateService {
  private readonly repository: ItemRepositoryPort;
  private readonly validator: ItemValidator;
  private readonly clock: () => number;

  constructor(repository: ItemRepositoryPort, validator: ItemValidator, clock: () => number = () => Date.now()) {
    this.repository = repository;
    this.validator = validator;
    this.clock = clock;
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
      photoState: existing.photoState,
      photoLocalId: existing.photoLocalId,
      createdAt: existing.createdAt,
      updatedAt: this.clock()
    };
    return this.repository.update(updatedItem);
  }
}
