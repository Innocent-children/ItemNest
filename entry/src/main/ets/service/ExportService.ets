import { AppError } from '../common/AppError';
import { Result } from '../common/Result';
import { ItemRepository } from '../data/repository/ItemRepository';
import { Item, ItemSummary } from '../model/Item';

export class ExportService {
  constructor(private itemRepo: ItemRepository) { }

  exportAllItems(): Result<string> {
    const itemsResult = this.itemRepo.listAllBasic();
    if (!itemsResult.ok) return Result.failure(itemsResult.error!);
    try {
      const items = itemsResult.getData();
      const exportData = items.map((item: Item) => ({
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        locationPath: item.locationPath,
        category: item.category,
        expirationDate: item.expirationDate,
        reminderDays: item.reminderDays,
        notes: item.notes
      }));
      const json = JSON.stringify({ version: 1, exportedAt: Date.now(), items: exportData }, null, 2);
      return Result.success(json);
    } catch (err) {
      return Result.failure(AppError.of('EXPORT_FAILED', String(err)));
    }
  }
}
