import { failure, Result, success } from '../common/Result';
import { Item, ItemSummary, PhotoState } from '../model/Item';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { ExpiryService } from './ExpiryService';

export class ItemListService {
  private readonly repository: ItemRepositoryPort;
  private readonly expiryService: ExpiryService;

  constructor(repository: ItemRepositoryPort, expiryService: ExpiryService) {
    this.repository = repository;
    this.expiryService = expiryService;
  }

  async listAll(now: Date = new Date()): Promise<Result<ItemSummary[]>> {
    const itemsResult = await this.repository.listAll();
    if (!itemsResult.ok) {
      return failure<ItemSummary[]>(itemsResult.getError());
    }
    return success(this.toSummaries(itemsResult.getData(), now));
  }

  toSummary(item: Item, now: Date = new Date()): ItemSummary {
    return {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      borrowedQuantity: item.borrowedQuantity,
      availableQuantity: item.borrowedQuantity === undefined ? undefined : Math.max(0, Math.round((item.quantity - item.borrowedQuantity) * 100) / 100),
      locationPath: item.locationPath,
      activeLocationPaths: item.activeLocationPaths,
      category: item.category,
      expirationDate: item.expirationDate,
      expiryStatus: this.expiryService.getExpiryStatus(item, now),
      stockStatus: this.expiryService.getStockStatus(item),
      photoLocalId: item.photoState === PhotoState.LOCAL ? item.photoLocalId : undefined,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt
    };
  }

  private toSummaries(items: Item[], now: Date): ItemSummary[] {
    const summaries: ItemSummary[] = [];
    for (let index = 0; index < items.length; index++) {
      summaries.push(this.toSummary(items[index], now));
    }
    return summaries;
  }
}
