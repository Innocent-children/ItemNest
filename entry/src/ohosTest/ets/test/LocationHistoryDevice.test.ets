import { describe, it, expect } from '@ohos/hypium';
import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { BatchDao } from '../../../main/ets/data/dao/BatchDao';
import { ItemDao } from '../../../main/ets/data/dao/ItemDao';
import { BatchRepository } from '../../../main/ets/data/repository/BatchRepository';
import { ItemRepository } from '../../../main/ets/data/repository/ItemRepository';
import { LocationRepository } from '../../../main/ets/data/repository/LocationRepository';
import { createBatchSchema } from '../../../main/ets/data/rdb/BatchSchema';
import { createItemSchema, DATABASE_VERSION } from '../../../main/ets/data/rdb/ItemSchema';
import { createLocationSchema } from '../../../main/ets/data/rdb/LocationSchema';
import { createLocationLabelSchema } from '../../../main/ets/data/rdb/LocationLabelSchema';
import { migrateToLatest, RdbDatabase } from '../../../main/ets/data/rdb/RdbDatabase';
import { ResultSetReader } from '../../../main/ets/data/rdb/ResultSetReader';
import { ItemUnit } from '../../../main/ets/model/Item';
import { BatchService } from '../../../main/ets/service/BatchService';
import { ItemCreateService } from '../../../main/ets/service/ItemCreateService';
import { ItemUpdateService } from '../../../main/ets/service/ItemUpdateService';
import { LocationService } from '../../../main/ets/service/LocationService';
import { buildLocationSuggestions } from '../../../main/ets/service/LocationSuggestions';

async function context(): Promise<Context> {
  return (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
}

async function cleanDatabase(ctx: Context, name: string): Promise<void> {
  try { await relationalStore.deleteRdbStore(ctx, name); } catch (_) {}
}

export default function locationHistoryDeviceTest() {
  describe('LocationHistoryDevice', () => {
    it('保存物品与批次记住位置，改名删除和重新打开仍保留历史', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-location-history-isolated-test.db';
      await cleanDatabase(ctx, name);
      const database = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(database));
      const batches = new BatchRepository(new BatchDao(database));
      const locations = new LocationRepository(database);
      try {
        const created = await new ItemCreateService(items, new ItemValidator(), () => 10)
          .create({ name: '测试物品', locationPath: '客厅', quantity: 1 });
        expect(created.ok).assertTrue();
        const item = created.getData();
        const batchService = new BatchService(batches, items, () => 20);
        const added = await batchService.create({ itemId: item.id, locationPath: '厨房 / 冰箱', quantity: 1 });
        expect(added.ok).assertTrue();
        expect((await batchService.update(added.getData().id,
          { itemId: item.id, locationPath: '书房', quantity: 1 })).ok).assertTrue();
        expect((await new ItemUpdateService(items, new ItemValidator(), () => 30, batches)
          .update(item.id, { name: item.name, quantity: 2, locationPath: '卧室' })).ok).assertTrue();
        const beforeRename = (await locations.listAll()).getData();
        const bedroom = beforeRename.find((location) => location.path === '卧室');
        expect(bedroom !== undefined).assertTrue();
        expect((await new LocationService(locations, items, () => 40, batches)
          .rename(bedroom!.id, '主卧')).ok).assertTrue();
        expect((await items.deleteConfirmed(item.id)).ok).assertTrue();
        database.close();
        const reopened = new RdbDatabase(ctx, name);
        try {
          const remembered = (await new LocationRepository(reopened).listAll()).getData();
          expect(buildLocationSuggestions(remembered, '').recentPaths[0]).assertEqual('主卧');
          expect(remembered.find((location) => location.id === bedroom!.id)?.lastUsedAt).assertEqual(30);
          expect(remembered.some((location) => location.path === '客厅')).assertTrue();
          expect(remembered.some((location) => location.path === '厨房 / 冰箱')).assertTrue();
        } finally { reopened.close(); }
      } finally { database.close(); await cleanDatabase(ctx, name); }
    });

    it('历史位置写入失败时物品默认批次和父位置一起回滚', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-location-rollback-isolated-test.db';
      await cleanDatabase(ctx, name);
      const database = new RdbDatabase(ctx, name);
      try {
        const store = await database.requireStore();
        await store.executeSql(`CREATE TRIGGER fail_location_leaf BEFORE INSERT ON managed_location
          WHEN NEW.path = '客厅 / 柜子' BEGIN SELECT RAISE(ABORT, 'test rollback'); END`);
        const items = new ItemRepository(new ItemDao(database));
        const result = await new ItemCreateService(items, new ItemValidator())
          .create({ name: '不会保存的物品', locationPath: '客厅 / 柜子' });
        expect(result.ok).assertFalse();
        expect((await items.listAll()).getData().length).assertEqual(0);
        expect((await new LocationRepository(database).listAll()).getData().length).assertEqual(0);
        const rows = await store.querySql('SELECT COUNT(*) AS count FROM batch');
        try {
          expect(ResultSetReader.goToFirstRow(rows)).assertTrue();
          expect(ResultSetReader.readLong(rows, 'count')).assertEqual(0);
        } finally { ResultSetReader.close(rows); }
      } finally { database.close(); await cleanDatabase(ctx, name); }
    });

    it('版本13升级补入物品批次位置且保留管理位置身份标签和停用状态', 0, async () => {
      const ctx = await context();
      const name = 'itemnest-location-upgrade-isolated-test.db';
      await cleanDatabase(ctx, name);
      const store = await relationalStore.getRdbStore(ctx, { name: name, securityLevel: relationalStore.SecurityLevel.S3 });
      try {
        const tx = await store.createTransaction();
        await createItemSchema(tx);
        await createBatchSchema(tx);
        await createLocationSchema(tx);
        await createLocationLabelSchema(tx);
        await tx.insert('managed_location', { id: 'living', name: '客厅', path: '客厅', active: 1, created_at: 1, updated_at: 1 });
        await tx.insert('managed_location', { id: 'disabled', name: '旧位置', path: '旧位置', active: 0, created_at: 1, updated_at: 1 });
        await tx.insert('location_label', { token: '12345678123412341234123456789012', location_id: 'living' });
        await tx.insert('item', { id: 'old-item', name: '旧物品', quantity: 1, unit: ItemUnit.PIECE,
          location_path: '客厅', created_at: 1, updated_at: 10 });
        await tx.insert('batch', { id: 'old-batch', item_id: 'old-item', quantity: 1, unit: ItemUnit.PIECE,
          location_path: '厨房 / 冰箱', created_at: 1, updated_at: 20 });
        await tx.execute('PRAGMA user_version = 13');
        await tx.commit();
        await migrateToLatest(store);
        expect(store.version).assertEqual(DATABASE_VERSION);
        const rows = await store.querySql('SELECT id, path, active, last_used_at FROM managed_location ORDER BY path');
        let hasLiving = false;
        let hasFridge = false;
        let disabled = false;
        try {
          while (ResultSetReader.goToNextRow(rows)) {
            const path = ResultSetReader.readString(rows, 'path');
            if (path === '客厅') { hasLiving = ResultSetReader.readString(rows, 'id') === 'living'; }
            if (path === '厨房 / 冰箱') { hasFridge = ResultSetReader.readLong(rows, 'last_used_at') === 20; }
            if (path === '旧位置') { disabled = ResultSetReader.readLong(rows, 'active') === 0; }
          }
        } finally { ResultSetReader.close(rows); }
        expect(hasLiving && hasFridge && disabled).assertTrue();
        const labels = await store.querySql('SELECT location_id FROM location_label');
        try {
          expect(ResultSetReader.goToFirstRow(labels)).assertTrue();
          expect(ResultSetReader.readString(labels, 'location_id')).assertEqual('living');
        } finally { ResultSetReader.close(labels); }
      } finally { store.close(); await cleanDatabase(ctx, name); }
    });
  });
}
