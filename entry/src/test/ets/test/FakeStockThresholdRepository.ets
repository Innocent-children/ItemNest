import { Result, success } from '../../../main/ets/common/Result';
import { StockThresholdRepositoryPort } from '../../../main/ets/data/repository/StockThresholdRepository';
import { StockThreshold } from '../../../main/ets/model/StockThreshold';

export class FakeStockThresholdRepository implements StockThresholdRepositoryPort {
  thresholds: StockThreshold[] = [];
  saveCallCount: number = 0;

  async save(threshold: StockThreshold): Promise<Result<StockThreshold>> {
    this.saveCallCount++;
    const index = this.thresholds.findIndex((current: StockThreshold) => current.itemId === threshold.itemId);
    if (index >= 0) {
      this.thresholds[index] = threshold;
    } else {
      this.thresholds.push(threshold);
    }
    return success(threshold);
  }

  async getByItemId(itemId: string): Promise<Result<StockThreshold | undefined>> {
    return success(this.thresholds.find((threshold: StockThreshold) => threshold.itemId === itemId));
  }

  async listEnabled(): Promise<Result<StockThreshold[]>> {
    return success(this.thresholds.filter((threshold: StockThreshold) => threshold.enabled));
  }
}
