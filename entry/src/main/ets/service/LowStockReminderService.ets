import { Result, success } from '../common/Result';
import { LowStockItem } from '../model/StockThreshold';

export class LowStockReminderService {
  getInAppNotice(items: LowStockItem[]): Result<string> {
    if (items.length === 0) {
      return success('暂无低库存物品');
    }
    return success(`有 ${items.length} 个物品低于阈值，请在应用内处理。`);
  }
}
