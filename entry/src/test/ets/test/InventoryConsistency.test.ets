import { describe, it, expect } from '@ohos/hypium';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { Result, success } from '../../../main/ets/common/Result';
import { BatchRepositoryPort } from '../../../main/ets/data/repository/BatchRepository';
import {
  INVENTORY_V10_MIGRATION_STATEMENTS,
  INVENTORY_V10_TRIGGER_NAMES
} from '../../../main/ets/data/rdb/InventoryIntegritySchema';
import { DATABASE_VERSION } from '../../../main/ets/data/rdb/ItemSchema';
import { Batch } from '../../../main/ets/model/Batch';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { BatchService } from '../../../main/ets/service/BatchService';
import { ItemUpdateService } from '../../../main/ets/service/ItemUpdateService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeBatchRepository implements BatchRepositoryPort {
  batches: Batch[] = [];

  async create(batch: Batch): Promise<Result<Batch>> {
    this.batches.push(batch);
    return success(batch);
  }

  async getById(batchId: string): Promise<Result<Batch | undefined>> {
    return success(this.batches.find((batch: Batch) => batch.id === batchId));
  }

  async listByItemId(itemId: string): Promise<Result<Batch[]>> {
    return success(this.batches.filter((batch: Batch) => batch.itemId === itemId));
  }

  async listAll(): Promise<Result<Batch[]>> {
    return success(this.batches.slice());
  }

  async update(batch: Batch): Promise<Result<Batch>> {
    const index = this.batches.findIndex((current: Batch) => current.id === batch.id);
    this.batches[index] = batch;
    return success(batch);
  }

  async deleteConfirmed(batchId: string): Promise<Result<void>> {
    const index = this.batches.findIndex((batch: Batch) => batch.id === batchId);
    this.batches.splice(index, 1);
    return success<void>(undefined);
  }
}

function buildItem(): Item {
  return {
    id: 'item-1',
    name: '牛奶',
    quantity: 10,
    unit: ItemUnit.BOX,
    locationPath: '厨房 / 冰箱',
    expirationDate: '2027-01-01',
    photoState: PhotoState.NONE,
    createdAt: 1,
    updatedAt: 1
  };
}

function buildDefaultBatch(): Batch {
  return {
    id: 'batch-default-item-1',
    itemId: 'item-1',
    quantity: 10,
    unit: ItemUnit.BOX,
    expirationDate: '2027-01-01',
    locationPath: '厨房 / 冰箱',
    createdAt: 1,
    updatedAt: 1
  };
}

export default function inventoryConsistencyTest() {
  describe('Inventory consistency', () => {
    it('批次校验真实日期并要求单位与父物品一致', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      const service = new BatchService(batches, items, () => 10);

      const invalidDate = await service.create({
        itemId: 'item-1', quantity: 1, unit: ItemUnit.BOX, expirationDate: '2026-02-29'
      });
      expect(invalidDate.ok).assertFalse();

      const mixedUnit = await service.create({ itemId: 'item-1', quantity: 1, unit: ItemUnit.PIECE });
      expect(mixedUnit.ok).assertFalse();

      const validLeapDate = await service.create({
        itemId: 'item-1', quantity: 1, unit: ItemUnit.BOX, expirationDate: '2024-02-29'
      });
      expect(validLeapDate.ok).assertTrue();
    });

    it('批次写操作不再执行第二次父物品写入', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new BatchService(batches, items, () => 10);

      const created = await service.create({ itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX });
      expect(created.ok).assertTrue();
      expect(items.items[0].quantity).assertEqual(10);
      expect(items.items[0].updatedAt).assertEqual(1);

      const updated = await service.update(created.getData().id, {
        itemId: 'item-1', quantity: 3, unit: ItemUnit.BOX
      });
      expect(updated.ok).assertTrue();
      expect(items.items[0].quantity).assertEqual(10);

      const deleted = await service.delete(created.getData().id);
      expect(deleted.ok).assertTrue();
      expect(items.items[0].updatedAt).assertEqual(1);
    });

    it('禁止删除最后一个批次并允许删除多个批次中的一个', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new BatchService(batches, items, () => 10);

      const rejected = await service.delete('batch-default-item-1');
      expect(rejected.ok).assertFalse();
      expect(batches.batches.length).assertEqual(1);

      const created = await service.create({ itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX });
      expect(created.ok).assertTrue();
      const deleted = await service.delete(created.getData().id);
      expect(deleted.ok).assertTrue();
      expect(batches.batches.length).assertEqual(1);
      expect(batches.batches[0].id).assertEqual('batch-default-item-1');
    });

    it('并发删除两个批次时仍至少保留一个批次', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new BatchService(batches, items, () => 10);
      const created = await service.create({ itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX });
      expect(created.ok).assertTrue();

      const results = await Promise.all([
        service.delete('batch-default-item-1'),
        service.delete(created.getData().id)
      ]);

      const successCount = results.filter((result: Result<void>) => result.ok).length;
      expect(successCount).assertEqual(1);
      expect(batches.batches.length).assertEqual(1);
    });

    it('存在批次时只允许直接修改非汇总字段', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new ItemUpdateService(items, new ItemValidator(), () => 20, batches);

      const quantityChanged = await service.update('item-1', {
        name: '牛奶', quantity: 11, unit: ItemUnit.BOX, expirationDate: '2027-01-01'
      });
      expect(quantityChanged.ok).assertFalse();

      const unitChanged = await service.update('item-1', {
        name: '牛奶', quantity: 10, unit: ItemUnit.PIECE, expirationDate: '2027-01-01'
      });
      expect(unitChanged.ok).assertFalse();

      const expirationChanged = await service.update('item-1', {
        name: '牛奶', quantity: 10, unit: ItemUnit.BOX, expirationDate: '2027-02-01'
      });
      expect(expirationChanged.ok).assertFalse();

      const metadataChanged = await service.update('item-1', {
        name: '低脂牛奶',
        quantity: 10,
        unit: ItemUnit.BOX,
        locationPath: '厨房 / 冷藏层',
        expirationDate: '2027-01-01'
      });
      expect(metadataChanged.ok).assertTrue();
      expect(items.items[0].name).assertEqual('低脂牛奶');
      expect(items.items[0].quantity).assertEqual(10);
    });

    it('v10 迁移声明完整的批次汇总与关联清理契约', 0, () => {
      const sql = INVENTORY_V10_MIGRATION_STATEMENTS.join('\n');
      expect(DATABASE_VERSION).assertEqual(10);
      expect(INVENTORY_V10_TRIGGER_NAMES.length).assertEqual(10);
      expect(sql.includes('WHERE NOT EXISTS')).assertTrue();
      expect(sql.includes('AFTER INSERT ON item')).assertTrue();
      expect(sql.includes('AFTER INSERT ON batch')).assertTrue();
      expect(sql.includes('AFTER UPDATE ON batch')).assertTrue();
      expect(sql.includes('AFTER DELETE ON batch')).assertTrue();
      expect(sql.includes('UPDATE trace_event SET batch_id = NULL')).assertTrue();
      expect(sql.includes('DELETE FROM stock_threshold')).assertTrue();
      expect(sql.includes('DELETE FROM reminder_record')).assertTrue();
      expect(sql.includes('DELETE FROM item_asset')).assertTrue();
    });
  });
}
