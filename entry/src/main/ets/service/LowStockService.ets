import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { Item } from '../model/Item';
import { LowStockItem, StockThreshold } from '../model/StockThreshold';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { StockThresholdRepositoryPort } from '../data/repository/StockThresholdRepository';

export class LowStockService {
  private readonly thresholds: StockThresholdRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;

  constructor(thresholds: StockThresholdRepositoryPort, items: ItemRepositoryPort, clock: () => number = () => Date.now()) {
    this.thresholds = thresholds;
    this.items = items;
    this.clock = clock;
  }

  async getThreshold(itemId: string): Promise<Result<StockThreshold | undefined>> {
    return this.thresholds.getByItemId(itemId);
  }

  async saveThreshold(itemId: string, threshold: number, enabled: boolean): Promise<Result<StockThreshold>> {
    const scaled = threshold * 100;
    const hasAtMostTwoDecimals = Math.abs(Math.round(scaled) - scaled) < 1e-9;
    if (!Number.isFinite(threshold) || threshold < 0 || !hasAtMostTwoDecimals) {
      return failure<StockThreshold>(new AppError(AppErrorCode.VALIDATION, '低库存阈值必须是最多两位小数的非负数'));
    }
    const itemResult = await this.items.getById(itemId);
    if (!itemResult.ok) {
      return failure<StockThreshold>(itemResult.getError());
    }
    if (itemResult.getData() === undefined) {
      return failure<StockThreshold>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    return this.thresholds.save({
      itemId: itemId,
      threshold: threshold,
      enabled: enabled,
      updatedAt: this.clock()
    });
  }

  async listLowStock(): Promise<Result<LowStockItem[]>> {
    const thresholdResult = await this.thresholds.listEnabled();
    if (!thresholdResult.ok) {
      return failure<LowStockItem[]>(thresholdResult.getError());
    }
    const itemsResult = await this.items.listAll();
    if (!itemsResult.ok) {
      return failure<LowStockItem[]>(itemsResult.getError());
    }
    const items = itemsResult.getData();
    const lowStock: LowStockItem[] = [];
    const thresholds = thresholdResult.getData();
    for (let index = 0; index < thresholds.length; index++) {
      const threshold = thresholds[index];
      const item = this.findItem(items, threshold.itemId);
      if (item !== undefined && item.quantity < threshold.threshold) {
        lowStock.push({
          itemId: item.id,
          name: item.name,
          quantity: item.quantity,
          threshold: threshold.threshold
        });
      }
    }
    return success(lowStock);
  }

  private findItem(items: Item[], itemId: string): Item | undefined {
    for (let index = 0; index < items.length; index++) {
      if (items[index].id === itemId) {
        return items[index];
      }
    }
    return undefined;
  }
}
