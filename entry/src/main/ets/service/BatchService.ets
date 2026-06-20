import { AppError } from '../common/AppError';
import { Result } from '../common/Result';
import { BatchRepository } from '../data/repository/BatchRepository';
import { Batch, BatchDraft, BatchSummary } from '../model/Batch';
import { ItemRepository } from '../data/repository/ItemRepository';
import { Item } from '../model/Item';
import { ExpiryService } from './ExpiryService';
import { ReminderService } from './ReminderService';

export class BatchService {
  constructor(
    private batchRepo: BatchRepository,
    private itemRepo: ItemRepository,
    private expiryService: ExpiryService,
    private reminderService: ReminderService | null
  ) { }

  create(draft: BatchDraft): Result<Batch> {
    const now = Date.now();
    const result = this.batchRepo.create(draft, now);
    if (result.ok) {
      this.refreshItemSummary(draft.itemId);
    }
    return result;
  }

  getById(id: string): Result<Batch | null> {
    return this.batchRepo.getById(id);
  }

  listByItemId(itemId: string): Result<Batch[]> {
    return this.batchRepo.listByItemId(itemId);
  }

  update(id: string, draft: BatchDraft): Result<void> {
    const now = Date.now();
    const result = this.batchRepo.update(id, draft, now);
    if (result.ok && draft.itemId) {
      this.refreshItemSummary(draft.itemId);
    }
    return result;
  }

  deleteById(id: string, itemId: string): Result<void> {
    const result = this.batchRepo.deleteById(id);
    if (result.ok) {
      this.refreshItemSummary(itemId);
    }
    return result;
  }

  getSummaries(itemId: string): Result<BatchSummary[]> {
    const batchesResult = this.batchRepo.listByItemId(itemId);
    if (!batchesResult.ok) {
      return Result.failure(batchesResult.error!);
    }
    const itemResult = this.itemRepo.getById(itemId);
    const itemName = (itemResult.ok && itemResult.getData()) ? itemResult.getData()!.name : '';
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    const summaries: BatchSummary[] = batchesResult.getData().map(batch => {
      const hasDate = batch.expirationDate !== null && batch.expirationDate.length > 0;
      const expired = hasDate && batch.expirationDate! < todayStr;
      const dueSoon = hasDate && !expired &&
        batch.expirationDate! <= this.addDays(todayStr, 7);
      return {
        id: batch.id,
        itemId: batch.itemId,
        itemName,
        quantity: batch.quantity,
        unit: batch.unit,
        expirationDate: batch.expirationDate,
        locationPath: batch.locationPath,
        dueSoon,
        expired
      };
    });
    return Result.success(summaries);
  }

  private refreshItemSummary(itemId: string): void {
    const itemResult = this.itemRepo.getById(itemId);
    if (!itemResult.ok || !itemResult.getData()) {
      return;
    }
    this.itemRepo.recalculateFromBatches(itemId);
    if (this.reminderService) {
      this.reminderService.rescheduleForItem(itemId);
    }
  }

  private addDays(dateStr: string, days: number): string {
    const d = new Date(dateStr);
    d.setDate(d.getDate() + days);
    return d.toISOString().split('T')[0];
  }
}
