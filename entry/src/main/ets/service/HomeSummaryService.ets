import { failure, Result, success } from '../common/Result';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item, ItemSummary, PhotoState } from '../model/Item';
import { StockStatus } from '../model/StockStatus';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { ExpiryService } from './ExpiryService';

export class HomeSummary {
  readonly recentItems: ItemSummary[];
  readonly dueSoonItems: ItemSummary[];
  readonly outOfStockItems: ItemSummary[];
  readonly dueSoonCount: number;
  readonly outOfStockCount: number;
  readonly expiryAttentionItems: ItemSummary[];

  constructor(recentItems: ItemSummary[], dueSoonItems: ItemSummary[], outOfStockItems: ItemSummary[], dueSoonCount: number, outOfStockCount: number, expiryAttentionItems: ItemSummary[] = dueSoonItems) {
    this.recentItems = recentItems;
    this.dueSoonItems = dueSoonItems;
    this.outOfStockItems = outOfStockItems;
    this.dueSoonCount = dueSoonCount;
    this.outOfStockCount = outOfStockCount;
    this.expiryAttentionItems = expiryAttentionItems;
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
    const recentResult = await this.repository.listRecent(10);
    if (!recentResult.ok) {
      return failure<HomeSummary>(recentResult.getError());
    }
    const itemsResult = await this.repository.listAll();
    if (!itemsResult.ok) {
      return failure<HomeSummary>(itemsResult.getError());
    }
    const recentItems = this.toSummaries(recentResult.getData(), now);
    const expiryAttentionItems: ItemSummary[] = [];
    const outOfStockItems: ItemSummary[] = [];
    let outOfStockCount = 0;
    const items = itemsResult.getData();
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const summary = this.toSummary(item, now);
      if (summary.expiryStatus === ExpiryStatus.DUE_SOON || summary.expiryStatus === ExpiryStatus.EXPIRED) {
        expiryAttentionItems.push(summary);
      }
      if (summary.stockStatus === StockStatus.OUT_OF_STOCK) {
        outOfStockCount++;
        if (outOfStockItems.length < 10) {
          outOfStockItems.push(summary);
        }
      }
    }
    expiryAttentionItems.sort((left: ItemSummary, right: ItemSummary) =>
      (left.expirationDate ?? '').localeCompare(right.expirationDate ?? ''));
    return success(new HomeSummary(recentItems, expiryAttentionItems.slice(0, 10), outOfStockItems,
      expiryAttentionItems.length, outOfStockCount, expiryAttentionItems));
  }

  private toSummaries(items: Item[], now: Date): ItemSummary[] {
    const summaries: ItemSummary[] = [];
    for (let index = 0; index < items.length; index++) {
      summaries.push(this.toSummary(items[index], now));
    }
    return summaries;
  }

  private toSummary(item: Item, now: Date): ItemSummary {
    return {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
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
}
