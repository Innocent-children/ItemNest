import { ItemListService } from './ItemListService';
import { failure, Result, success } from '../common/Result';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item, ItemSummary } from '../model/Item';
import { StockStatus } from '../model/StockStatus';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { StockThresholdRepositoryPort } from '../data/repository/StockThresholdRepository';
import { StockThreshold } from '../model/StockThreshold';
import { ExpiryService } from './ExpiryService';

export class HomeSummary {
  readonly totalItemCount: number;
  readonly unconfiguredStockCount: number;
  readonly recentItems: ItemSummary[];
  readonly restockItems: ItemSummary[];
  readonly dueSoonCount: number;
  readonly restockCount: number;
  readonly expiryAttentionItems: ItemSummary[];

  constructor(recentItems: ItemSummary[], expiryAttentionItems: ItemSummary[], restockItems: ItemSummary[], totalItemCount: number,
    unconfiguredStockCount: number) {
    this.totalItemCount = totalItemCount;
    this.unconfiguredStockCount = unconfiguredStockCount;
    this.recentItems = recentItems;
    this.expiryAttentionItems = expiryAttentionItems;
    this.restockItems = restockItems;
    this.dueSoonCount = expiryAttentionItems.length;
    this.restockCount = restockItems.length;
  }
}

export class HomeSummaryService {
  private readonly repository: ItemRepositoryPort;
  private readonly listItems: ItemListService;
  private readonly thresholds: StockThresholdRepositoryPort;

  constructor(repository: ItemRepositoryPort, expiryService: ExpiryService, thresholds: StockThresholdRepositoryPort) {
    this.repository = repository;
    this.listItems = new ItemListService(repository, expiryService);
    this.thresholds = thresholds;
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
    const thresholdResult = await this.thresholds.listEnabled();
    if (!thresholdResult.ok) { return failure<HomeSummary>(thresholdResult.getError()); }
    const thresholds = thresholdResult.getData();
    const recentItems = this.toSummaries(recentResult.getData(), now);
    const expiryAttentionItems: ItemSummary[] = [];
    const restockItems: ItemSummary[] = [];
    const items = itemsResult.getData();
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const summary = this.listItems.toSummary(item, now);
      if (summary.expiryStatus === ExpiryStatus.DUE_SOON || summary.expiryStatus === ExpiryStatus.EXPIRED) {
        expiryAttentionItems.push(summary);
      }
      const threshold = thresholds.find((value: StockThreshold) => value.itemId === item.id);
      if (summary.stockStatus === StockStatus.OUT_OF_STOCK || (threshold !== undefined && item.quantity < threshold.threshold)) {
        restockItems.push(summary);
      }
    }
    expiryAttentionItems.sort((left: ItemSummary, right: ItemSummary) =>
      (left.expirationDate ?? '').localeCompare(right.expirationDate ?? ''));
    return success(new HomeSummary(recentItems, expiryAttentionItems, restockItems, items.length,
      items.filter((item: Item) => !thresholds.some((threshold: StockThreshold) => threshold.itemId === item.id)).length));
  }

  private toSummaries(items: Item[], now: Date): ItemSummary[] {
    const summaries: ItemSummary[] = [];
    for (let index = 0; index < items.length; index++) {
      summaries.push(this.listItems.toSummary(items[index], now));
    }
    return summaries;
  }

}
