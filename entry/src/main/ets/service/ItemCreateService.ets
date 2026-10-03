import { ItemValidator } from '../common/ItemValidator';
import { failure, Result } from '../common/Result';
import { Item, ItemDraft, PhotoState } from '../model/Item';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';

export class ItemCreateService {
  private readonly repository: ItemRepositoryPort;
  private readonly validator: ItemValidator;
  private readonly clock: () => number;

  constructor(repository: ItemRepositoryPort, validator: ItemValidator, clock: () => number = () => Date.now()) {
    this.repository = repository;
    this.validator = validator;
    this.clock = clock;
  }

  async create(draft: ItemDraft): Promise<Result<Item>> {
    const validated = this.validator.validate(draft);
    if (!validated.ok) {
      return failure<Item>(validated.getError());
    }
    const now = this.clock();
    const item: Item = {
      id: this.createStableId(now),
      name: validated.getData().name,
      quantity: validated.getData().quantity,
      unit: validated.getData().unit,
      locationPath: validated.getData().locationPath,
      category: validated.getData().category,
      expirationDate: validated.getData().expirationDate,
      reminderDays: validated.getData().reminderDays,
      notes: validated.getData().notes,
      barcode: validated.getData().barcode,
      photoState: PhotoState.NONE,
      createdAt: now,
      updatedAt: now
    };
    return this.repository.create(item);
  }

  private createStableId(now: number): string {
    const randomPart = Math.floor(Math.random() * 1000000000).toString(36);
    return `item-${now.toString(36)}-${randomPart}`;
  }
}
