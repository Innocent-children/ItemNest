import { LocationLabelRepository } from '../../../main/ets/data/repository/LocationLabelRepository';
import { describe, it, expect } from '@ohos/hypium';
import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { ItemDao } from '../../../main/ets/data/dao/ItemDao';
import { BatchDao } from '../../../main/ets/data/dao/BatchDao';
import { ItemRepository } from '../../../main/ets/data/repository/ItemRepository';
import { BatchRepository } from '../../../main/ets/data/repository/BatchRepository';
import { TraceEventRepository } from '../../../main/ets/data/repository/TraceEventRepository';
import { RdbDatabase, migrateToLatest } from '../../../main/ets/data/rdb/RdbDatabase';
import { createItemSchema, addItemBarcode, DATABASE_VERSION } from '../../../main/ets/data/rdb/ItemSchema';
import { createAssetSchema } from '../../../main/ets/data/rdb/AssetSchema';
import { createBatchSchema } from '../../../main/ets/data/rdb/BatchSchema';
import { createStockThresholdSchema } from '../../../main/ets/data/rdb/StockThresholdSchema';
import { createLocationSchema } from '../../../main/ets/data/rdb/LocationSchema';
import { createCategorySchema } from '../../../main/ets/data/rdb/CategorySchema';
import { createSearchHistorySchema } from '../../../main/ets/data/rdb/SearchHistorySchema';
import { createInventoryIntegritySchema } from '../../../main/ets/data/rdb/InventoryIntegritySchema';
import { ResultSetReader } from '../../../main/ets/data/rdb/ResultSetReader';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { TraceEvent, TraceEventType } from '../../../main/ets/model/TraceEvent';
import { BatchService } from '../../../main/ets/service/BatchService';
import { LendingService } from '../../../main/ets/service/LendingService';


import { Result, success } from '../../../main/ets/common/Result';
import { AssetDao } from '../../../main/ets/data/dao/AssetDao';
import { ReminderDao } from '../../../main/ets/data/dao/ReminderDao';
import { AssetRepository } from '../../../main/ets/data/repository/AssetRepository';
import { CategoryRepository } from '../../../main/ets/data/repository/CategoryRepository';
import { LocationRepository } from '../../../main/ets/data/repository/LocationRepository';
import { ReminderRepository } from '../../../main/ets/data/repository/ReminderRepository';
import { StockThresholdRepository } from '../../../main/ets/data/repository/StockThresholdRepository';
import { PreferenceRepositoryPort } from '../../../main/ets/data/repository/PreferenceRepository';
import { DEFAULT_USER_PREFERENCES, UserPreferences } from '../../../main/ets/model/UserPreferences';
import { ExportService } from '../../../main/ets/service/ExportService';
import { PortableBackupService } from '../../../main/ets/service/PortableBackupService';
import { PortableFileStore } from '../../../main/ets/service/PortableFileStore';
import { PreferenceService } from '../../../main/ets/service/PreferenceService';
import { ReminderService } from '../../../main/ets/service/ReminderService';
import { ReminderAdapter } from '../../../main/ets/service/adapter/ReminderAdapter';

class IsolatedPreferences implements PreferenceRepositoryPort {
  async get(): Promise<Result<UserPreferences>> { return success(DEFAULT_USER_PREFERENCES); }
  async save(value: UserPreferences): Promise<Result<UserPreferences>> { return success(value); }
}

class IsolatedReminderAdapter implements ReminderAdapter {
  async schedule(_item: Item, _scheduledAt: number): Promise<Result<number>> { return success(1); }
  async cancel(_id: number): Promise<Result<void>> { return success<void>(undefined); }
}

class CapturedSafetyFileStore extends PortableFileStore {
  safetyText: string = '';
  async writeSafetyBackup(text: string): Promise<string> {
    this.safetyText = text;
    return 'isolated-test-safety';
  }
}

export async function seedLegacyDatabase(store: relationalStore.RdbStore, version: number): Promise<void> {
  const tx = await store.createTransaction();
  await createItemSchema(tx);
  await tx.execute('CREATE TABLE reminder_record (item_id TEXT PRIMARY KEY NOT NULL, scheduled_at INTEGER, system_reminder_id INTEGER, status TEXT NOT NULL, error_summary TEXT, updated_at INTEGER NOT NULL)');
  await createAssetSchema(tx);
  await createBatchSchema(tx);
  await createStockThresholdSchema(tx);
  await tx.execute('CREATE TABLE trace_event (id TEXT PRIMARY KEY NOT NULL, item_id TEXT NOT NULL, batch_id TEXT, type TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity >= 0), counterpart TEXT, note TEXT, created_at INTEGER NOT NULL)');
  await createLocationSchema(tx);
  await createCategorySchema(tx);
  await createSearchHistorySchema(tx);
  await createInventoryIntegritySchema(tx);
  if (version >= 11) {
    await addItemBarcode(tx);
  }
  await tx.execute(`PRAGMA user_version = ${version}`);
  await tx.commit();
}

async function context(): Promise<Context> {
  return (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
}

async function cleanDatabase(ctx: Context, name: string): Promise<void> {
  try { await relationalStore.deleteRdbStore(ctx, name); } catch (_) {}
}

function fixtureItem(id: string, quantity: number): Item {
  return { id: id, name: '独立测试物品', quantity: quantity, unit: ItemUnit.PIECE,
    locationPath: '旧位置', photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1 };
}

export default function inventoryUpgradeDeviceTest() {
  describe('Inventory v12 device safety', () => {

    it('真实数据库备份恢复保留关联归还撤销备注消耗并先备份当前数据', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-backup-roundtrip-isolated-test.db';
      await cleanDatabase(ctx, name);
      const db = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(db));
      const batches = new BatchRepository(new BatchDao(db));
      const traces = new TraceEventRepository(db);
      const lending = new LendingService(traces, items);
      const thresholds = new StockThresholdRepository(db);
      const reminders = new ReminderService(new ReminderRepository(new ReminderDao(db)),
        new PreferenceService(new IsolatedPreferences()), new IsolatedReminderAdapter(), items);
      const files = new CapturedSafetyFileStore(ctx);
      const portable = new PortableBackupService(new ExportService(items, batches,
        new LocationRepository(db), new CategoryRepository(db), traces), thresholds,
        new AssetRepository(new AssetDao(db)), files, db, reminders);
      try {
        await items.create(fixtureItem('backup-owned', 6));
        const accidental = (await lending.borrow('backup-owned', 1, '错误人', undefined, '错误借出')).getData();
        expect((await lending.voidEvent('backup-owned', accidental.id)).ok).assertTrue();
        const borrowed = (await lending.borrow('backup-owned', 3, 'Alice', undefined, '原约定')).getData();
        expect((await lending.returnItem('backup-owned', 1, undefined, '原归还备注', borrowed.id)).ok).assertTrue();
        expect((await new BatchService(batches, items).consume('backup-owned', 1)).ok).assertTrue();
        await thresholds.save({ itemId: 'backup-owned', threshold: 2, enabled: true, updatedAt: 1 });
        const labels = new LocationLabelRepository(db);
        expect((await new LocationRepository(db).create({ id: 'label-location', name: '标签测试位置', path: '标签测试位置',
          active: true, createdAt: 1, updatedAt: 1 })).ok).assertTrue();
        await labels.save({ token: '12345678123412341234123456789012', locationId: 'label-location' });
        const exported = await portable.exportJson();
        expect(exported.ok).assertTrue();
        const preview = portable.preview(exported.getData()).getData();
        expect(preview.thresholdCount).assertEqual(1);
        expect(preview.locationLabelCount).assertEqual(1);
        await labels.remove('12345678123412341234123456789012');
        expect(preview.traceEventCount).assertEqual(4);
        expect(preview.sampleNames[0]).assertEqual('独立测试物品');
        await items.create(fixtureItem('temporary-replacement', 3));
        expect((await portable.restore(exported.getData(), true)).ok).assertTrue();
        expect(files.safetyText.includes('temporary-replacement')).assertTrue();
        expect((await labels.list())[0].locationId).assertEqual('label-location');
        const restoredLocations = (await new LocationRepository(db).listAll()).getData();
        expect(restoredLocations.find((location) => location.path === '旧位置')?.lastUsedAt).assertEqual(1);
        expect((await items.listAll()).getData().length).assertEqual(1);
        const state = (await lending.getState('backup-owned')).getData();
        expect(state.totalQuantity).assertEqual(5);
        expect(state.borrowedQuantity).assertEqual(2);
        const history = (await traces.listByItemId('backup-owned')).getData();
        expect(history.length).assertEqual(4);
        expect(history.find((event: TraceEvent) => event.id === accidental.id)?.voidedAt !== undefined).assertTrue();
        const returned = history.find((event: TraceEvent) => event.type === TraceEventType.RETURN) as TraceEvent;
        expect(returned.note).assertEqual('原归还备注');
        expect(returned.returnAllocations?.[0].borrowEventId).assertEqual(borrowed.id);
        expect((await thresholds.getByItemId('backup-owned')).getData()?.threshold).assertEqual(2);
      } finally { db.close(); await cleanDatabase(ctx, name); }
    });

    it('v11保留原资料与超借记录并仅汇总有库存批次到期日', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-legacy-isolated-test.db';
      await cleanDatabase(ctx, name);
      const store = await relationalStore.getRdbStore(ctx, { name: name, securityLevel: relationalStore.SecurityLevel.S3 });
      try {
        await seedLegacyDatabase(store, 11);
        await store.insert('item', { id: 'legacy', name: '原物品', quantity: 0, unit: '个',
          location_path: '旧位置', expiration_date: '2020-01-01', notes: '原备注', barcode: 'LEGACY123',
          photo_state: 'NONE', created_at: 1, updated_at: 1 });
        await store.insert('batch', { id: 'fresh', item_id: 'legacy', quantity: 5, unit: '个',
          expiration_date: '2100-11-01', location_path: '新位置', notes: '新批次', created_at: 2, updated_at: 2 });
        await store.insert('trace_event', { id: 'early', item_id: 'legacy', type: 'RETURN', quantity: 1,
          note: '无法匹配也保留', created_at: 1 });
        await store.insert('trace_event', { id: 'borrow-old', item_id: 'legacy', type: 'BORROW', quantity: 9,
          counterpart: '原借用人', note: '原借出约定', created_at: 2 });
        await store.insert('trace_event', { id: 'return-old', item_id: 'legacy', type: 'RETURN', quantity: 2,
          note: '原归还备注', created_at: 3 });
        await store.insert('reminder_record', { item_id: 'legacy', status: 'FAILED', error_summary: '旧失败信息', updated_at: 1 });
        await migrateToLatest(store);
        expect(store.version).assertEqual(DATABASE_VERSION);
        let rs = await store.querySql("SELECT name, quantity, expiration_date, notes, barcode FROM item WHERE id = 'legacy'");
        try {
          expect(ResultSetReader.goToFirstRow(rs)).assertTrue();
          expect(ResultSetReader.readString(rs, 'name')).assertEqual('原物品');
          expect(ResultSetReader.readDouble(rs, 'quantity')).assertEqual(5);
          expect(ResultSetReader.readString(rs, 'expiration_date')).assertEqual('2100-11-01');
          expect(ResultSetReader.readString(rs, 'notes')).assertEqual('原备注');
          expect(ResultSetReader.readString(rs, 'barcode')).assertEqual('LEGACY123');
        } finally { ResultSetReader.close(rs); }
        rs = await store.querySql('SELECT id, quantity, counterpart, note, return_allocations_json FROM trace_event ORDER BY created_at');
        try {
          expect(ResultSetReader.goToNextRow(rs)).assertTrue();
          expect(ResultSetReader.readString(rs, 'id')).assertEqual('early');
          expect(ResultSetReader.readString(rs, 'return_allocations_json')).assertEqual('[]');
          expect(ResultSetReader.goToNextRow(rs)).assertTrue();
          expect(ResultSetReader.readDouble(rs, 'quantity')).assertEqual(9);
          expect(ResultSetReader.readString(rs, 'counterpart')).assertEqual('原借用人');
          expect(ResultSetReader.readString(rs, 'note')).assertEqual('原借出约定');
          expect(ResultSetReader.goToNextRow(rs)).assertTrue();
          expect(ResultSetReader.readDouble(rs, 'quantity')).assertEqual(2);
          expect(ResultSetReader.readString(rs, 'return_allocations_json')?.includes('borrow-old')).assertTrue();
          expect(ResultSetReader.goToNextRow(rs)).assertFalse();
        } finally { ResultSetReader.close(rs); }
        await migrateToLatest(store);
        rs = await store.querySql("SELECT error_summary FROM reminder_record WHERE item_id = 'legacy'");
        try {
          expect(ResultSetReader.goToFirstRow(rs)).assertTrue();
          expect(ResultSetReader.readString(rs, 'error_summary')).assertEqual('旧失败信息');
        } finally { ResultSetReader.close(rs); }
      } finally { store.close(); await cleanDatabase(ctx, name); }
    });

    it('v11升级中途失败回滚新增列与版本并可重试且原记录不变', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-upgrade-rollback-isolated-test.db';
      await cleanDatabase(ctx, name);
      const store = await relationalStore.getRdbStore(ctx, { name: name, securityLevel: relationalStore.SecurityLevel.S3 });
      try {
        await seedLegacyDatabase(store, 11);
        await store.insert('item', { id: 'original', name: '原物品', quantity: 3, unit: '个',
          photo_state: 'NONE', created_at: 1, updated_at: 1 });
        await store.insert('trace_event', { id: 'loan', item_id: 'original', type: 'BORROW', quantity: 2,
          counterpart: '原借用人', note: '原借出备注', created_at: 2 });
        await store.insert('trace_event', { id: 'returned', item_id: 'original', type: 'RETURN', quantity: 1,
          note: '原归还备注', created_at: 3 });
        await store.executeSql("CREATE TRIGGER reject_isolated_upgrade BEFORE UPDATE ON trace_event BEGIN SELECT RAISE(ABORT, 'isolated upgrade failure'); END");
        let failed = false;
        try { await migrateToLatest(store); } catch (_) { failed = true; }
        expect(failed).assertTrue();
        expect(store.version).assertEqual(11);
        const columns = await store.querySql('PRAGMA table_info(trace_event)');
        let hasNewColumn = false;
        try {
          while (ResultSetReader.goToNextRow(columns)) {
            if (ResultSetReader.readString(columns, 'name') === 'return_allocations_json') { hasNewColumn = true; }
          }
        } finally { ResultSetReader.close(columns); }
        expect(hasNewColumn).assertFalse();
        const rows = await store.querySql('SELECT id,quantity,note FROM trace_event ORDER BY created_at');
        try {
          expect(ResultSetReader.goToNextRow(rows)).assertTrue();
          expect(ResultSetReader.readString(rows, 'id')).assertEqual('loan');
          expect(ResultSetReader.readDouble(rows, 'quantity')).assertEqual(2);
          expect(ResultSetReader.readString(rows, 'note')).assertEqual('原借出备注');
          expect(ResultSetReader.goToNextRow(rows)).assertTrue();
          expect(ResultSetReader.readString(rows, 'note')).assertEqual('原归还备注');
          expect(ResultSetReader.goToNextRow(rows)).assertFalse();
        } finally { ResultSetReader.close(rows); }
        await store.executeSql('DROP TRIGGER reject_isolated_upgrade');
        await migrateToLatest(store);
        expect(store.version).assertEqual(DATABASE_VERSION);
      } finally { store.close(); await cleanDatabase(ctx, name); }
    });

    it('真实事务限制超借和消耗并保持归还关联及总量', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-service-isolated-test.db';
      await cleanDatabase(ctx, name);
      const db = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(db));
      const batches = new BatchRepository(new BatchDao(db));
      const events = new TraceEventRepository(db);
      const lending = new LendingService(events, items);
      const batchService = new BatchService(batches, items);
      try {
        expect((await items.create(fixtureItem('owned', 6))).ok).assertTrue();
        const borrowed = await lending.borrow('owned', 3, 'Alice', undefined, '约定');
        expect(borrowed.ok).assertTrue();
        expect((await lending.borrow('owned', 4, 'Bob')).ok).assertFalse();
        expect((await batchService.consume('owned', 4)).ok).assertFalse();
        expect((await batchService.consume('owned', 2)).ok).assertTrue();
        let state = await lending.getState('owned');
        expect(state.ok).assertTrue();
        expect(state.getData().totalQuantity).assertEqual(4);
        expect(state.getData().availableQuantity).assertEqual(1);
        expect((await lending.returnItem('owned', 2, undefined, '归还备注', borrowed.getData().id)).ok).assertTrue();
        state = await lending.getState('owned');
        expect(state.getData().totalQuantity).assertEqual(4);
        expect(state.getData().borrowedQuantity).assertEqual(1);
        expect(state.getData().availableQuantity).assertEqual(3);
        expect((await batchService.consume('owned', 3)).ok).assertTrue();
        const history = await events.listByItemId('owned');
        expect(history.getData().filter((event: TraceEvent) => event.type === TraceEventType.CONSUME).length).assertEqual(2);
        const returned = history.getData().find((event: TraceEvent) => event.type === TraceEventType.RETURN) as TraceEvent;
        expect(returned.counterpart).assertEqual('Alice');
        expect(returned.note).assertEqual('归还备注');
        expect(returned.returnAllocations?.[0].borrowEventId).assertEqual(borrowed.getData().id);
      } finally { db.close(); await cleanDatabase(ctx, name); }
    });

    it('并发借出和消耗不会共同占用同一份在手库存', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-concurrency-isolated-test.db';
      await cleanDatabase(ctx, name);
      const db = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(db));
      const batches = new BatchRepository(new BatchDao(db));
      const lending = new LendingService(new TraceEventRepository(db), items);
      const batchService = new BatchService(batches, items);
      try {
        await items.create(fixtureItem('concurrent', 6));
        const results = await Promise.all([lending.borrow('concurrent', 4, 'Alice'), batchService.consume('concurrent', 3)]);
        expect(results.filter((result) => result.ok).length).assertEqual(1);
        const state = (await lending.getState('concurrent')).getData();
        expect(state.totalQuantity >= state.borrowedQuantity).assertTrue();
      } finally { db.close(); await cleanDatabase(ctx, name); }
    });

    it('批次位置进入父位置查询且统一纠正单位不改数量', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-v12-location-isolated-test.db';
      await cleanDatabase(ctx, name);
      const db = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(db));
      const batches = new BatchRepository(new BatchDao(db));
      const batchService = new BatchService(batches, items);
      try {
        await items.create(fixtureItem('located', 2));
        const batch = (await batches.listByItemId('located')).getData()[0];
        expect((await batchService.update(batch.id, { itemId: 'located', quantity: 2, unit: ItemUnit.PIECE,
          locationPath: '新位置 / 架子', expirationDate: '2100-11-01' })).ok).assertTrue();
        const found = await items.list(new ItemQuery('', '新位置'));
        expect(found.getData().length).assertEqual(1);
        expect(found.getData()[0].activeLocationPaths?.[0]).assertEqual('新位置 / 架子');
        const item = (await items.getById('located')).getData() as Item;
        item.unit = ItemUnit.BOX;
        item.updatedAt = 3;
        expect((await items.update(item)).ok).assertTrue();
        const adjusted = (await batches.listByItemId('located')).getData()[0];
        expect(adjusted.quantity).assertEqual(2);
        expect(adjusted.unit).assertEqual(ItemUnit.BOX);
        expect((await batchService.delete(adjusted.id)).ok).assertTrue();
        expect((await items.getById('located')).getData()?.quantity).assertEqual(0);
        expect((await batches.listByItemId('located')).getData().length).assertEqual(1);
      } finally { db.close(); await cleanDatabase(ctx, name); }
    });
  });
}
