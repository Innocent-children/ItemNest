import { failure, Result, success } from '../common/Result';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item, ItemSummary } from '../model/Item';
import { StockStatus } from '../model/StockStatus';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { ExpiryService } from './ExpiryService';

export class HomeSummary {
  readonly recentItems: ItemSummary[];
  readonly dueSoonItems: ItemSummary[];
  readonly outOfStockItems: ItemSummary[];
  readonly dueSoonCount: number;
  readonly outOfStockCount: number;

  constructor(recentItems: ItemSummary[], dueSoonItems: ItemSummary[], outOfStockItems: ItemSummary[], dueSoonCount: number, outOfStockCount: number) {
    this.recentItems = recentItems;
    this.dueSoonItems = dueSoonItems;
    this.outOfStockItems = outOfStockItems;
    this.dueSoonCount = dueSoonCount;
    this.outOfStockCount = outOfStockCount;
  }
}

export class HomeSummaryService {
  private readonly repository: ItemRepositoryPort;
  private readonly expiryService: ExpiryService;

  constructor(repository: ItemRepositoryPort, expiryService: ExpiryService) {
    this.repository = repository;
    this.expiryService = expiryService;
  }

  async getSummary(now: Date = new Date()): Promise<Result<HomeSummary>> {
    const itemsResult = await this.repository.listAll();
    if (!itemsResult.ok) {
      return failure<HomeSummary>(itemsResult.getError());
    }
    const recentItems: ItemSummary[] = [];
    const dueSoonItems: ItemSummary[] = [];
    const outOfStockItems: ItemSummary[] = [];
    let dueSoonCount = 0;
    let outOfStockCount = 0;
    const items = itemsResult.getData();
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const summary = this.toSummary(item, now);
      if (recentItems.length < 10) {
        recentItems.push(summary);
      }
      if (summary.expiryStatus === ExpiryStatus.DUE_SOON) {
        dueSoonCount++;
        if (dueSoonItems.length < 10) {
          dueSoonItems.push(summary);
        }
      }
      if (summary.stockStatus === StockStatus.OUT_OF_STOCK) {
        outOfStockCount++;
        if (outOfStockItems.length < 10) {
          outOfStockItems.push(summary);
        }
      }
    }
    return success(new HomeSummary(recentItems, dueSoonItems, outOfStockItems, dueSoonCount, outOfStockCount));
  }

  private toSummary(item: Item, now: Date): ItemSummary {
    return {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      locationPath: item.locationPath,
      category: item.category,
      expirationDate: item.expirationDate,
      expiryStatus: this.expiryService.getExpiryStatus(item, now),
      stockStatus: this.expiryService.getStockStatus(item),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt
    };
  }
}
