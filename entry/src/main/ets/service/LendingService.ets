import { AppError } from '../common/AppError';
import { Result } from '../common/Result';
import { BatchService } from './BatchService';
import { Batch } from '../model/Batch';

export class LendingService {
  constructor(private batchService: BatchService) { }

  lend(batchId: string, itemId: string, count: number): Result<Batch> {
    const batchResult = this.batchService.getById(batchId);
    if (!batchResult.ok || !batchResult.getData()) {
      return Result.failure(AppError.of('BATCH_NOT_FOUND', '批次不存在'));
    }
    const batch = batchResult.getData()!;
    if (batch.quantity < count) {
      return Result.failure(AppError.of('INSUFFICIENT_QUANTITY', 库存不足，当前仅有 \));
    }
    batch.quantity -= count;
    const draft = { itemId, quantity: batch.quantity, unit: batch.unit };
    const updateResult = this.batchService.update(batchId, draft);
    if (!updateResult.ok) return Result.failure(updateResult.error!);
    this.recordTraceEvent(batchId, itemId, 'LEND', count, batch.quantity + count, batch.quantity);
    return Result.success(batch);
  }

  returnBack(batchId: string, itemId: string, count: number): Result<void> {
    const batchResult = this.batchService.getById(batchId);
    if (!batchResult.ok || !batchResult.getData()) {
      return Result.failure(AppError.of('BATCH_NOT_FOUND', '批次不存在'));
    }
    const batch = batchResult.getData()!;
    const beforeQty = batch.quantity;
    batch.quantity += count;
    const draft = { itemId, quantity: batch.quantity, unit: batch.unit };
    const updateResult = this.batchService.update(batchId, draft);
    if (!updateResult.ok) return Result.failure(updateResult.error!);
    this.recordTraceEvent(batchId, itemId, 'RETURN', count, beforeQty, batch.quantity);
    return Result.success();
  }

  private recordTraceEvent(_batchId: string, _itemId: string, _type: string, _count: number, _before: number, _after: number): void {
    // TraceEvent 持久化在 T082 的 TraceEventRepository 完成后接入
  }
}
