import { AppError } from '../common/AppError';
import { Result } from '../common/Result';
import { ItemRepository } from '../data/repository/ItemRepository';
import { StockThreshold } from '../model/StockThreshold';

export class LowStockService {
  private thresholds: Map<string, number> = new Map();

  constructor(private itemRepo: ItemRepository) { }

  setThreshold(itemId: string | null, category: string | null, minQuantity: number): void {
    const key = itemId ?? cat:\;
    this.thresholds.set(key, minQuantity);
  }

  getThreshold(itemId: string, category: string): number {
    const byItem = this.thresholds.get(itemId);
    if (byItem !== undefined) return byItem;
    const byCat = this.thresholds.get(cat:\);
    if (byCat !== undefined) return byCat;
    return 1;
  }

  isLowStock(itemId: string, quantity: number, category: string): boolean {
    if (quantity > 0) return false;
    const threshold = this.getThreshold(itemId, category);
    return quantity <= threshold;
  }

  getLowStockItems(): Result<{ itemId: string; name: string; quantity: number; threshold: number }[]> {
    const itemsResult = this.itemRepo.listAllBasic();
    if (!itemsResult.ok) return Result.failure(itemsResult.error!);
    const result = itemsResult.getData()
      .filter(i => i.quantity <= 0)
      .map(i => ({ itemId: i.id, name: i.name, quantity: i.quantity, threshold: this.getThreshold(i.id, i.category) }));
    return Result.success(result);
  }
}
