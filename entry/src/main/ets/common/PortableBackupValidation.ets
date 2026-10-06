import { LocationLabel } from '../model/LocationLabel';
import { AppError, AppErrorCode } from './AppError';
import { failure, Result, success } from './Result';
import { ImportPreview, ItemTraceExportPayload } from './ImportValidation';
import { ItemValidator } from './ItemValidator';
import { Item, PhotoState } from '../model/Item';
import { isItemUnit } from '../model/Item';
import { allocateLegacyReturns, TraceEvent, TraceEventType } from '../model/TraceEvent';
import { StockThreshold } from '../model/StockThreshold';

export const PORTABLE_BACKUP_VERSION: string = 'itemtrace.backup.v2';
export const MAX_BACKUP_BYTES: number = 32 * 1024 * 1024;
export const MAX_PHOTO_BYTES: number = 5 * 1024 * 1024;
export const MAX_TOTAL_PHOTO_BYTES: number = 20 * 1024 * 1024;

export interface BackupPhoto {
  itemId: string;
  bytesBase64: string;
}

export interface PortableBackupPayload extends ItemTraceExportPayload {
  locationLabels?: LocationLabel[];
  thresholds: StockThreshold[];
  photos: BackupPhoto[];
}

export class PortableBackupValidation {
  private readonly validator: ItemValidator = new ItemValidator();

  validate(text: string): Result<PortableBackupPayload> {
    if (text.length === 0 || text.length > MAX_BACKUP_BYTES) {
      return this.invalid('备份文件为空或超过 32 MB');
    }
    try {
      const payload = JSON.parse(text) as PortableBackupPayload;
      if (payload === null || payload.version !== PORTABLE_BACKUP_VERSION ||
        !Number.isFinite(payload.exportedAt) || !Array.isArray(payload.items) ||
        !Array.isArray(payload.batches) || !Array.isArray(payload.locations) ||
        !Array.isArray(payload.categories) || !Array.isArray(payload.traceEvents) ||
        !Array.isArray(payload.thresholds) || !Array.isArray(payload.photos)) {
        return this.invalid('备份文件版本或结构不受支持');
      }
      if (payload.items.length > 5000 || payload.batches.length > 20000 ||
        payload.locations.length > 5000 || payload.categories.length > 1000 ||
        payload.traceEvents.length > 50000 || payload.thresholds.length > 5000 ||
        payload.photos.length > 5000) {
        return this.invalid('备份文件的记录数超过上限');
      }
      const itemIds = new Set<string>();
      const batchIds = new Set<string>();
      const batchOwners = new Map<string, string>();
      const photoIds = new Set<string>();
      const thresholdIds = new Set<string>();
      const locationIds = new Set<string>();
      const locationParents = new Map<string, string>();
      const categoryIds = new Set<string>();
      const categoryNames = new Set<string>();
      const traceIds = new Set<string>();
      const itemUnits = new Map<string, string>();
      const batchCounts = new Map<string, number>();
      const batchTotals = new Map<string, number>();
      const earliestDates = new Map<string, string>();
      const legacyEarliestDates = new Map<string, string>();
      let encodedPhotoLength = 0;
      for (const item of payload.items) {
        if (!item || !this.validId(item.id) || itemIds.has(item.id) ||
          !this.validator.validate({ name: item.name, quantity: item.quantity, unit: item.unit,
            locationPath: item.locationPath, category: item.category, expirationDate: item.expirationDate,
            reminderDays: item.reminderDays, notes: item.notes, barcode: item.barcode }).ok ||
          !Number.isFinite(item.quantity) || !Number.isFinite(item.createdAt) ||
          !Number.isFinite(item.updatedAt) || item.photoState !== PhotoState.NONE ||
          item.photoLocalId !== undefined) {
          return this.invalid('备份文件包含无效物品或外部图片引用');
        }
        itemIds.add(item.id);
        itemUnits.set(item.id, item.unit);
      }
      for (const batch of payload.batches) {
        if (!batch || !this.validId(batch.id) || batchIds.has(batch.id) ||
          !itemIds.has(batch.itemId) || !isItemUnit(batch.unit) ||
          batch.unit !== itemUnits.get(batch.itemId) ||
          !Number.isFinite(batch.quantity) || batch.quantity < 0 ||
          Math.abs(Math.round(batch.quantity * 100) - batch.quantity * 100) >= 1e-9 ||
          !this.validator.validateExpirationDate(batch.expirationDate).ok ||
          !this.validator.validateLocationPath(batch.locationPath).ok ||
          (batch.notes !== undefined && (typeof batch.notes !== 'string' || batch.notes.length > 500)) ||
          !Number.isFinite(batch.createdAt) || !Number.isFinite(batch.updatedAt)) {
          return this.invalid('备份文件包含无效批次关系');
        }
        batchIds.add(batch.id);
        batchOwners.set(batch.id, batch.itemId);
        batchCounts.set(batch.itemId, (batchCounts.get(batch.itemId) ?? 0) + 1);
        batchTotals.set(batch.itemId, (batchTotals.get(batch.itemId) ?? 0) + batch.quantity);
        if (batch.expirationDate !== undefined && batch.expirationDate.length > 0) {
          const legacyDate = legacyEarliestDates.get(batch.itemId);
          if (legacyDate === undefined || batch.expirationDate < legacyDate) {
            legacyEarliestDates.set(batch.itemId, batch.expirationDate);
          }
          const currentDate = earliestDates.get(batch.itemId);
          if (batch.quantity > 0 && (currentDate === undefined || batch.expirationDate < currentDate)) {
            earliestDates.set(batch.itemId, batch.expirationDate);
          }
        }
      }
      for (const item of payload.items) {
        const total = batchTotals.get(item.id) ?? 0;
        if ((batchCounts.get(item.id) ?? 0) === 0 ||
          Math.abs(Math.round(total * 100) / 100 - item.quantity) >= 1e-9 ||
          (earliestDates.get(item.id) !== item.expirationDate &&
            legacyEarliestDates.get(item.id) !== item.expirationDate)) {
          return this.invalid('备份文件的批次汇总与物品不一致');
        }
        // Earlier v2 files included depleted batches in the date rollup. Keep their records and
        // rebuild only this derived date, so a valid old backup remains recoverable.
        item.expirationDate = earliestDates.get(item.id);
      }
      for (const location of payload.locations) {
        if (!location || !this.validId(location.id) || locationIds.has(location.id) ||
          typeof location.name !== 'string' || location.name.length === 0 || location.name.length > 80 ||
          typeof location.path !== 'string' || location.path.length === 0 || location.path.length > 200 ||
          typeof location.active !== 'boolean' || !Number.isFinite(location.createdAt) ||
          !Number.isFinite(location.updatedAt)) {
          return this.invalid('备份文件包含无效位置');
        }
        locationIds.add(location.id);
        if (location.parentId !== undefined) {
          locationParents.set(location.id, location.parentId);
        }
      }
      for (const location of payload.locations) {
        if (location.parentId !== undefined && !locationIds.has(location.parentId)) {
          return this.invalid('备份文件包含悬空的位置层级');
        }
        const visited = new Set<string>();
        let current: string | undefined = location.id;
        while (current !== undefined) {
          if (visited.has(current)) {
            return this.invalid('备份文件包含循环的位置层级');
          }
          visited.add(current);
          current = locationParents.get(current);
        }
      }
      if (payload.locationLabels !== undefined) {
        if (!Array.isArray(payload.locationLabels) || payload.locationLabels.length > 10000) {
          return this.invalid('备份中的收纳标签结构无效');
        }
        const tokens = new Set<string>();
        for (const label of payload.locationLabels) {
          if (!label || typeof label.token !== 'string' || !/^[a-fA-F0-9-]{32,36}$/.test(label.token) ||
            tokens.has(label.token) || !locationIds.has(label.locationId)) {
            return this.invalid('备份包含重复或没有对应位置的收纳标签');
          }
          tokens.add(label.token);
        }
      }
      for (const category of payload.categories) {
        if (!category || !this.validId(category.id) || categoryIds.has(category.id) ||
          typeof category.name !== 'string' || category.name.length === 0 || category.name.length > 40 ||
          categoryNames.has(category.name) || typeof category.active !== 'boolean' ||
          typeof category.systemPreset !== 'boolean' ||
          !Number.isFinite(category.createdAt) || !Number.isFinite(category.updatedAt)) {
          return this.invalid('备份文件包含无效分类');
        }
        categoryIds.add(category.id);
        categoryNames.add(category.name);
      }
      for (const trace of payload.traceEvents) {
        if (!trace || !this.validId(trace.id) || traceIds.has(trace.id) || !itemIds.has(trace.itemId) ||
          (trace.batchId !== undefined && !batchIds.has(trace.batchId)) ||
          (trace.batchId !== undefined && batchOwners.get(trace.batchId) !== trace.itemId) ||
          (trace.type !== TraceEventType.BORROW && trace.type !== TraceEventType.RETURN &&
            trace.type !== TraceEventType.CONSUME &&
            trace.type !== TraceEventType.QUANTITY_ADJUST && trace.type !== TraceEventType.IMPORT &&
            trace.type !== TraceEventType.EXPORT) ||
          !Number.isFinite(trace.quantity) || trace.quantity < 0 || !Number.isFinite(trace.createdAt) ||
          (trace.counterpart !== undefined && typeof trace.counterpart !== 'string') ||
          (trace.note !== undefined && typeof trace.note !== 'string') ||
          (trace.voidedAt !== undefined && !Number.isFinite(trace.voidedAt)) ||
          (trace.legacyAllocated !== undefined && typeof trace.legacyAllocated !== 'boolean') ||
          (trace.returnAllocations !== undefined && !Array.isArray(trace.returnAllocations)) ||
          (trace.type !== TraceEventType.RETURN &&
            (trace.returnAllocations !== undefined || trace.legacyAllocated === true))) {
          return this.invalid('备份文件包含无效借还记录');
        }
        traceIds.add(trace.id);
      }
      allocateLegacyReturns(payload.traceEvents);
      if (!this.validReturnRelations(payload.traceEvents)) {
        return this.invalid('备份文件包含无效归还关联');
      }
      for (const threshold of payload.thresholds) {
        if (!threshold || !itemIds.has(threshold.itemId) || thresholdIds.has(threshold.itemId) ||
          !Number.isFinite(threshold.threshold) || threshold.threshold < 0 ||
          Math.abs(Math.round(threshold.threshold * 100) - threshold.threshold * 100) >= 1e-9 ||
          typeof threshold.enabled !== 'boolean' || !Number.isFinite(threshold.updatedAt)) {
          return this.invalid('备份文件包含无效库存阈值');
        }
        thresholdIds.add(threshold.itemId);
      }
      for (const photo of payload.photos) {
        if (!photo || !itemIds.has(photo.itemId) || photoIds.has(photo.itemId) ||
          typeof photo.bytesBase64 !== 'string' || photo.bytesBase64.length === 0 ||
          photo.bytesBase64.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4 ||
          !/^[A-Za-z0-9+/]+={0,2}$/.test(photo.bytesBase64)) {
          return this.invalid('备份文件包含无效照片');
        }
        encodedPhotoLength += photo.bytesBase64.length;
        if (encodedPhotoLength > Math.ceil(MAX_TOTAL_PHOTO_BYTES / 3) * 4 + payload.photos.length * 4) {
          return this.invalid('备份照片总量超过 20 MB');
        }
        photoIds.add(photo.itemId);
      }
      return success(payload);
    } catch (_) {
      return this.invalid('备份文件不是有效 JSON');
    }
  }

  preview(payload: PortableBackupPayload): ImportPreview {
    return new ImportPreview(payload.items.length, payload.batches.length, payload.locations.length,
      payload.categories.length, payload.traceEvents.length, payload.exportedAt, payload.photos.length,
      payload.thresholds.length, payload.items.slice(0, 5).map((item: Item) => item.name), payload.locationLabels?.length ?? 0);
  }

  private validReturnRelations(events: TraceEvent[]): boolean {
    const byId = new Map<string, TraceEvent>();
    const returnedByLoan = new Map<string, number>();
    for (const event of events) {
      byId.set(event.id, event);
    }
    for (const event of events) {
      if (event.type !== TraceEventType.RETURN || event.returnAllocations === undefined) {
        continue;
      }
      const relationIds = new Set<string>();
      let allocated = 0;
      for (const relation of event.returnAllocations) {
        if (!relation || !this.validId(relation.borrowEventId) || relationIds.has(relation.borrowEventId) ||
          !Number.isFinite(relation.quantity) || relation.quantity <= 0 ||
          Math.abs(Math.round(relation.quantity * 100) - relation.quantity * 100) >= 1e-9) {
          return false;
        }
        const borrowed = byId.get(relation.borrowEventId);
        if (borrowed === undefined || borrowed.type !== TraceEventType.BORROW ||
          borrowed.itemId !== event.itemId ||
          (event.voidedAt === undefined && borrowed.voidedAt !== undefined)) {
          return false;
        }
        relationIds.add(relation.borrowEventId);
        allocated += relation.quantity;
        if (event.voidedAt === undefined) {
          const returned = (returnedByLoan.get(borrowed.id) ?? 0) + relation.quantity;
          if (returned > borrowed.quantity + 1e-9) {
            return false;
          }
          returnedByLoan.set(borrowed.id, returned);
        }
      }
      if (allocated > event.quantity + 1e-9 ||
        (event.legacyAllocated !== true && Math.abs(allocated - event.quantity) >= 1e-9)) {
        return false;
      }
    }
    return true;
  }

  private validId(value: string): boolean {
    return typeof value === 'string' && value.length > 0 && value.length <= 128 &&
      value.indexOf('/') < 0 && value.indexOf('\\') < 0;
  }

  private invalid(message: string): Result<PortableBackupPayload> {
    return failure<PortableBackupPayload>(new AppError(AppErrorCode.VALIDATION, message));
  }
}
