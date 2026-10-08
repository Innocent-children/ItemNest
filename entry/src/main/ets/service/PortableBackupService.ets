import { LocationLabelRepository } from '../data/repository/LocationLabelRepository';
import { BackupProgressService } from './BackupProgressService';
import { Context } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { BackupPhotoCodec } from '../common/BackupPhotoCodec';
import { AppError, AppErrorCode } from '../common/AppError';
import { ImportPreview, ItemNestExportPayload } from '../common/ImportValidation';
import { BackupPhoto, MAX_BACKUP_BYTES, MAX_TOTAL_PHOTO_BYTES,
  PORTABLE_BACKUP_VERSION, PortableBackupPayload, PortableBackupValidation } from '../common/PortableBackupValidation';
import { failure, Result, success } from '../common/Result';
import { AppEventBus } from '../common/AppEventBus';
import { AssetRepositoryPort } from '../data/repository/AssetRepository';
import { StockThresholdRepository } from '../data/repository/StockThresholdRepository';
import { RdbDatabase } from '../data/rdb/RdbDatabase';
import { migrateLendingRelations } from '../data/rdb/TraceEventSchema';
import { backfillLocationUsage } from '../data/dao/LocationDao';
import { Item, PhotoState } from '../model/Item';
import { ItemAsset, AssetSource } from '../model/ItemAsset';
import { ExportService } from './ExportService';
import { PortableFileStore } from './PortableFileStore';
import { ReminderService } from './ReminderService';

export class PortableBackupService {
  private readonly progress?: BackupProgressService;
  private readonly exporter: ExportService;
  private readonly thresholds: StockThresholdRepository;
  private readonly assets: AssetRepositoryPort;
  private readonly files: PortableFileStore;
  private readonly database: RdbDatabase;
  private readonly reminders: ReminderService;
  private readonly validation: PortableBackupValidation = new PortableBackupValidation();
  private readonly photoCodec: BackupPhotoCodec = new BackupPhotoCodec();

  constructor(exporter: ExportService, thresholds: StockThresholdRepository, assets: AssetRepositoryPort,
    files: PortableFileStore, database: RdbDatabase, reminders: ReminderService, progress?: BackupProgressService) {
    this.progress = progress;
    this.exporter = exporter;
    this.thresholds = thresholds;
    this.assets = assets;
    this.files = files;
    this.database = database;
    this.reminders = reminders;
  }

  async exportJson(progress?: BackupProgressService): Promise<Result<string>> {
    const exported = await this.exporter.exportJson();
    if (!exported.ok) {
      return failure<string>(exported.getError());
    }
    const thresholdResult = await this.thresholds.listAll();
    if (!thresholdResult.ok) {
      return failure<string>(thresholdResult.getError());
    }
    try {
      const data = JSON.parse(exported.getData()) as ItemNestExportPayload;
      const items: Item[] = [];
      const photos: BackupPhoto[] = [];
      let photoBytes = 0;
      for (const item of data.items) {
        if (progress !== undefined) { await progress.report('整理物品与照片', items.length, data.items.length); }
        if (item.photoState === PhotoState.LOCAL && item.photoLocalId === undefined) {
          return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '物品照片记录不完整，无法生成完整备份'));
        }
        items.push({ id: item.id, name: item.name, quantity: item.quantity, unit: item.unit,
          locationPath: item.locationPath, category: item.category, expirationDate: item.expirationDate,
          reminderDays: item.reminderDays, notes: item.notes, barcode: item.barcode,
          photoState: PhotoState.NONE, photoLocalId: undefined,
          createdAt: item.createdAt, updatedAt: item.updatedAt });
        if (item.photoLocalId === undefined) {
          continue;
        }
        const assetResult = await this.assets.getById(item.photoLocalId);
        if (!assetResult.ok || assetResult.getData() === undefined || assetResult.getData()?.itemId !== item.id) {
          return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '物品照片记录不完整，无法生成完整备份'));
        }
        const bytes = await this.files.readOwnedPhoto(assetResult.getData()!.localPath);
        if (!this.photoCodec.isSupportedImage(bytes)) {
          return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '物品照片格式不受支持，无法生成完整备份'));
        }
        photoBytes += bytes.length;
        if (photoBytes > MAX_TOTAL_PHOTO_BYTES) {
          return failure<string>(new AppError(AppErrorCode.VALIDATION, '照片总量超过 20 MB，无法创建单文件备份'));
        }
        photos.push({ itemId: item.id, bytesBase64: this.photoCodec.encode(bytes) });
      }
      const payload: PortableBackupPayload = {
        version: PORTABLE_BACKUP_VERSION,
        exportedAt: data.exportedAt,
        items: items,
        batches: data.batches,
        locations: data.locations,
        categories: data.categories,
        traceEvents: data.traceEvents,
        thresholds: thresholdResult.getData(),
        locationLabels: await new LocationLabelRepository(this.database).list(),
        photos: photos
      };
      const text = JSON.stringify(payload);
      if (new util.TextEncoder().encodeInto(text).length > MAX_BACKUP_BYTES) {
        return failure<string>(new AppError(AppErrorCode.VALIDATION, '备份数据超过 32 MB'));
      }
      const preview = this.preview(text);
      if (!preview.ok) {
        return failure<string>(new AppError(AppErrorCode.VALIDATION, '现有数据不符合备份校验，无法生成可恢复文件'));
      }
      return success(text);
    } catch (_) {
      return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '生成备份失败，请检查本地照片后重试'));
    }
  }

  async saveToUserFile(context: Context): Promise<Result<boolean>> {
    await this.progress?.begin('正在准备备份');
    let message = '备份未完成';
    try {
      const exported = await this.exportJson(this.progress);
      if (!exported.ok) { message = exported.getError().message; return failure<boolean>(exported.getError()); }
      this.progress?.check();
      await this.progress?.report('选择备份保存位置', 0, 0);
      const saved = await this.files.saveBackup(context, exported.getData(), () => this.progress?.seal());
      message = !saved.ok ? saved.getError().message : saved.getData() ? '备份已保存' : '已取消保存';
      return saved;
    } catch (_) { return failure<boolean>(new AppError(AppErrorCode.ASSET_STORAGE, '备份已取消或保存失败')); }
    finally { await this.progress?.finish(message); }
  }

  async selectUserFile(context: Context): Promise<Result<string | undefined>> {
    return this.files.selectBackup(context);
  }

  async saveSafetyBackup(context: Context): Promise<Result<boolean>> {
    return this.files.saveSafetyBackup(context);
  }

  preview(text: string): Result<ImportPreview> {
    const validated = this.validation.validate(text);
    if (!validated.ok) {
      return failure<ImportPreview>(validated.getError());
    }
    const payload = validated.getData();
    for (const photo of payload.photos) {
      try {
        this.photoCodec.decode(photo.bytesBase64);
      } catch (_) {
        return failure<ImportPreview>(new AppError(AppErrorCode.VALIDATION, '备份包含无法解码的图片'));
      }
    }
    return success(this.validation.preview(payload));
  }

  async previewCurrent(): Promise<Result<ImportPreview>> {
    const exported = await this.exporter.exportJson();
    if (!exported.ok) {
      return failure<ImportPreview>(exported.getError());
    }
    const thresholds = await this.thresholds.listAll();
    if (!thresholds.ok) {
      return failure<ImportPreview>(thresholds.getError());
    }
    try {
      const data = JSON.parse(exported.getData()) as ItemNestExportPayload;
      const locationLabelCount = (await new LocationLabelRepository(this.database).list()).length;
      const photoCount = data.items.filter((item: Item) => item.photoState === PhotoState.LOCAL).length;
      return success(new ImportPreview(data.items.length, data.batches.length, data.locations.length,
        data.categories.length, data.traceEvents.length, undefined, photoCount, thresholds.getData().length,
        data.items.slice(0, 5).map((item: Item) => item.name), locationLabelCount));
    } catch (_) {
      return failure<ImportPreview>(new AppError(AppErrorCode.DATABASE_READ, '无法核对当前数据，请重试预览'));
    }
  }

  async restore(text: string, confirmed: boolean): Promise<Result<string>> {
    await this.progress?.begin('正在准备恢复');
    let message = '恢复未完成';
    try {
      const result = await this.restoreContents(text, confirmed);
      message = result.ok ? result.getData() : result.getError().message;
      return result;
    } catch (_) { return failure<string>(new AppError(AppErrorCode.DATABASE_WRITE, '恢复已取消或失败，现有数据已保留')); }
    finally { await this.progress?.finish(message); }
  }

  private async restoreContents(text: string, confirmed: boolean): Promise<Result<string>> {
    if (!confirmed) {
      return failure<string>(new AppError(AppErrorCode.VALIDATION, '恢复前需要明确确认'));
    }
    const preview = this.preview(text);
    if (!preview.ok) {
      return failure<string>(preview.getError());
    }
    const validated = this.validation.validate(text);
    if (!validated.ok) {
      return failure<string>(validated.getError());
    }
    const current = await this.exportJson(this.progress);
    if (!current.ok) {
      return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '无法保存恢复前的安全备份，现有数据未改动'));
    }
    try {
      await this.files.writeSafetyBackup(current.getData());
    } catch (_) {
      return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '无法保存恢复前的安全备份，现有数据未改动'));
    }
    const rawCurrent = await this.exporter.exportJson();
    if (!rawCurrent.ok) {
      return failure<string>(rawCurrent.getError());
    }
    const oldItems = (JSON.parse(rawCurrent.getData()) as ItemNestExportPayload).items;
    const oldPhotoPaths: string[] = [];
    for (const item of oldItems) {
      if (item.photoLocalId !== undefined) {
        const assetResult = await this.assets.getById(item.photoLocalId);
        if (!assetResult.ok || assetResult.getData() === undefined) {
          return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '无法核对现有照片，数据尚未恢复'));
        }
        oldPhotoPaths.push(assetResult.getData()!.localPath);
      }
    }
    const payload = validated.getData();
    const staged: ItemAsset[] = [];
    const cancelledItems: Item[] = [];
    try {
      for (const photo of payload.photos) {
        await this.progress?.report('恢复照片', staged.length, payload.photos.length);
        const bytes = this.photoCodec.decode(photo.bytesBase64);
        const id = `restored-${Date.now()}-${Math.floor(Math.random() * 1000000000)}`;
        const path = await this.files.writeOwnedPhoto(id, bytes);
        staged.push({ id: id, itemId: photo.itemId, localPath: path,
          source: AssetSource.PHOTO_PICKER, createdAt: Date.now() });
      }
      await this.progress?.report('正在更新物品数据', 0, 0);
      this.progress?.seal();
      for (const item of oldItems) {
        const cancelled = await this.reminders.cancelForItem(item.id);
        if (!cancelled.ok) {
          throw cancelled.getError();
        }
        cancelledItems.push(item);
      }
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        await this.replaceRows(store, payload, staged);
      });
    } catch (_) {
      for (const asset of staged) {
        try { await this.files.removeOwnedPhoto(asset.localPath); } catch (_) {}
      }
      for (const item of cancelledItems) {
        try { await this.reminders.reconcileLatest(item.id); } catch (_) {}
      }
      return failure<string>(new AppError(AppErrorCode.DATABASE_WRITE, '恢复失败，数据库已回滚；恢复前备份已在应用内保留'));
    }
    AppEventBus.notifyDataChanged();
    let cleanupFailed = false;
    for (const item of payload.items) {
      try {
        const scheduled = await this.reminders.reconcileLatest(item.id);
        if (!scheduled.ok) {
          cleanupFailed = true;
        }
      } catch (_) {
        cleanupFailed = true;
      }
    }
    for (const path of oldPhotoPaths) {
      try { await this.files.removeOwnedPhoto(path); } catch (_) { cleanupFailed = true; }
    }
    return success(cleanupFailed
      ? '数据已恢复；部分提醒或旧照片需要稍后重试清理。恢复前备份已在应用内保留。'
      : '数据已恢复，恢复前备份已在应用内保留。');
  }

  private async replaceRows(store: relationalStore.Transaction, payload: PortableBackupPayload, assets: ItemAsset[]): Promise<void> {
    await store.execute('DELETE FROM item');
    await store.execute('DELETE FROM location_label');
    await store.execute('DELETE FROM managed_location');
    await store.execute('DELETE FROM managed_category');
    for (const location of payload.locations) {
      await store.insert('managed_location', { id: location.id, name: location.name, parent_id: location.parentId ?? null,
        path: location.path, active: location.active ? 1 : 0, created_at: location.createdAt, updated_at: location.updatedAt,
        last_used_at: location.lastUsedAt ?? null });
    }
    for (const label of payload.locationLabels ?? []) {
      await store.insert('location_label', { token: label.token, location_id: label.locationId });
    }
    for (const category of payload.categories) {
      await store.insert('managed_category', { id: category.id, name: category.name, active: category.active ? 1 : 0,
        system_preset: category.systemPreset ? 1 : 0, created_at: category.createdAt, updated_at: category.updatedAt });
    }
    for (const item of payload.items) {
      await store.insert('item', { id: item.id, name: item.name, quantity: item.quantity, unit: item.unit,
        location_path: item.locationPath ?? null, category: item.category ?? null,
        expiration_date: item.expirationDate ?? null, reminder_days: item.reminderDays ?? null,
        notes: item.notes ?? null, barcode: item.barcode ?? null, photo_state: PhotoState.NONE,
        photo_local_id: null, created_at: item.createdAt, updated_at: item.updatedAt });
    }
    await store.execute('DELETE FROM batch');
    for (const batch of payload.batches) {
      await store.insert('batch', { id: batch.id, item_id: batch.itemId, quantity: batch.quantity, unit: batch.unit,
        expiration_date: batch.expirationDate ?? null, location_path: batch.locationPath ?? null,
        notes: batch.notes ?? null, created_at: batch.createdAt, updated_at: batch.updatedAt });
    }
    for (const threshold of payload.thresholds) {
      await store.insert('stock_threshold', { item_id: threshold.itemId, threshold: threshold.threshold,
        enabled: threshold.enabled ? 1 : 0, updated_at: threshold.updatedAt });
    }
    for (const trace of payload.traceEvents) {
      await store.insert('trace_event', { id: trace.id, item_id: trace.itemId, batch_id: trace.batchId ?? null,
        type: trace.type, quantity: trace.quantity, counterpart: trace.counterpart ?? null,
        note: trace.note ?? null, created_at: trace.createdAt, voided_at: trace.voidedAt ?? null,
        return_allocations_json: trace.returnAllocations === undefined ? null : JSON.stringify(trace.returnAllocations),
        legacy_allocated: trace.legacyAllocated === true ? 1 : 0 });
    }
    await migrateLendingRelations(store);
    for (const asset of assets) {
      await store.insert('item_asset', { id: asset.id, item_id: asset.itemId, local_path: asset.localPath,
        source: asset.source, created_at: asset.createdAt });
      const predicates = new relationalStore.RdbPredicates('item');
      predicates.equalTo('id', asset.itemId);
      await store.update({ photo_state: PhotoState.LOCAL, photo_local_id: asset.id }, predicates);
    }
    for (const item of payload.items) {
      const predicates = new relationalStore.RdbPredicates('item');
      predicates.equalTo('id', item.id);
      await store.update({ updated_at: item.updatedAt }, predicates);
    }
    await backfillLocationUsage(store);
  }
}
