import { describe, it, expect } from '@ohos/hypium';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { failure, Result, success } from '../../../main/ets/common/Result';
import { BatchRepositoryPort } from '../../../main/ets/data/repository/BatchRepository';
import {
  INVENTORY_V10_MIGRATION_STATEMENTS,
  INVENTORY_V10_TRIGGER_NAMES,
  INVENTORY_V12_MIGRATION_STATEMENTS
} from '../../../main/ets/data/rdb/InventoryIntegritySchema';
import { DATABASE_VERSION } from '../../../main/ets/data/rdb/ItemSchema';
import { Batch } from '../../../main/ets/model/Batch';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { BatchService } from '../../../main/ets/service/BatchService';
import { ItemUpdateService } from '../../../main/ets/service/ItemUpdateService';
import { isSameOrDescendantLocation, planConsumption, validateInventoryReduction } from '../../../main/ets/service/InventoryPolicy';
import { ItemSearchService } from '../../../main/ets/service/ItemSearchService';
import { ItemListService } from '../../../main/ets/service/ItemListService';
import { ExpiryService } from '../../../main/ets/service/ExpiryService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeBatchRepository implements BatchRepositoryPort {
  batches: Batch[] = [];
  lastConsumeTime: number = 0;

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
    const itemBatches = this.batches.filter((batch: Batch) => batch.itemId === this.batches[index].itemId);
    if (itemBatches.length <= 1) {
      this.batches[index].quantity = 0;
    } else {
      this.batches.splice(index, 1);
    }
    return success<void>(undefined);
  }

  async consumeAtomic(itemId: string, quantity: number, batchId: string | undefined, now: number): Promise<Result<void>> {
    const planned = planConsumption(this.batches.filter((batch: Batch) => batch.itemId === itemId), quantity, 0, batchId);
    if (!planned.ok) {
      return failure<void>(planned.getError());
    }
    this.lastConsumeTime = now;
    const allocations = planned.getData();
    for (let index = 0; index < allocations.length; index++) {
      allocations[index].batch.quantity = allocations[index].remainingQuantity;
    }
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

    it('清空最后一个批次保留记录并允许删除多个批次中的一个', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new BatchService(batches, items, () => 10);

      const cleared = await service.delete('batch-default-item-1');
      expect(cleared.ok).assertTrue();
      expect(batches.batches.length).assertEqual(1);
      expect(batches.batches[0].quantity).assertEqual(0);
      expect(batches.batches[0].expirationDate).assertEqual('2027-01-01');

      const created = await service.create({ itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX });
      expect(created.ok).assertTrue();
      const deleted = await service.delete(created.getData().id);
      expect(deleted.ok).assertTrue();
      expect(batches.batches.length).assertEqual(1);
      expect(batches.batches[0].id).assertEqual('batch-default-item-1');
    });

    it('并发删除两个批次时最后一个仅清空且保留批次记录', 0, async () => {
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
      expect(successCount).assertEqual(2);
      expect(batches.batches.length).assertEqual(1);
      expect(batches.batches[0].quantity).assertEqual(0);
    });

    it('存在批次时允许统一纠正单位但不直接改汇总数量和到期日', 0, async () => {
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
      expect(unitChanged.ok).assertTrue();
      expect(items.items[0].unit).assertEqual(ItemUnit.PIECE);
      expect(items.items[0].quantity).assertEqual(10);

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


    it('消耗忽略零库存旧批次并优先扣最早到期批次', 0, () => {
      const empty = buildDefaultBatch();
      empty.id = 'empty';
      empty.quantity = 0;
      empty.expirationDate = '2020-01-01';
      const first = buildDefaultBatch();
      first.id = 'first';
      first.quantity = 1;
      first.expirationDate = '2026-01-01';
      const later = buildDefaultBatch();
      later.id = 'later';
      later.quantity = 2;
      later.expirationDate = '2027-01-01';
      const noDate = buildDefaultBatch();
      noDate.id = 'no-date';
      noDate.quantity = 3;
      noDate.expirationDate = undefined;
      const plan = planConsumption([noDate, later, empty, first], 2.5, 0);
      expect(plan.ok).assertTrue();
      expect(plan.getData().length).assertEqual(2);
      expect(plan.getData()[0].batch.id).assertEqual('first');
      expect(plan.getData()[0].remainingQuantity).assertEqual(0);
      expect(plan.getData()[1].batch.id).assertEqual('later');
      expect(plan.getData()[1].remainingQuantity).assertEqual(0.5);
      expect(first.quantity).assertEqual(1);
      expect(later.quantity).assertEqual(2);
    });

    it('消耗不能侵占未归还数量并精确扣除两位小数', 0, () => {
      const batch = buildDefaultBatch();
      batch.quantity = 1.25;
      expect(planConsumption([batch], 0.26, 1).ok).assertFalse();
      const plan = planConsumption([batch], 0.25, 1);
      expect(plan.ok).assertTrue();
      expect(plan.getData()[0].remainingQuantity).assertEqual(1);
      expect(planConsumption([batch], 0.01, 1.5).ok).assertFalse();
      expect(planConsumption([batch], 0, 0).ok).assertFalse();
      expect(planConsumption([batch], 0.001, 0).ok).assertFalse();
      expect(planConsumption([batch], Number.NaN, 0).ok).assertFalse();
    });

    it('指定批次数量不足时不挪用其他批次', 0, () => {
      const chosen = buildDefaultBatch();
      chosen.id = 'chosen';
      chosen.quantity = 1;
      const other = buildDefaultBatch();
      other.id = 'other';
      other.quantity = 5;
      expect(planConsumption([chosen, other], 2, 0, 'chosen').ok).assertFalse();
      expect(chosen.quantity).assertEqual(1);
      expect(other.quantity).assertEqual(5);
    });

    it('历史超借允许保持和补足库存但不能扩大缺口', 0, () => {
      expect(validateInventoryReduction(10, 10, 12).ok).assertTrue();
      expect(validateInventoryReduction(10, 11, 12).ok).assertTrue();
      expect(validateInventoryReduction(10, 13, 12).ok).assertTrue();
      expect(validateInventoryReduction(10, 9, 12).ok).assertFalse();
      expect(validateInventoryReduction(15, 12, 12).ok).assertTrue();
      expect(validateInventoryReduction(15, 11.99, 12).ok).assertFalse();
    });

    it('父位置包含子位置但不匹配同名前缀的位置', 0, () => {
      expect(isSameOrDescendantLocation('厨房 / 冰箱 / 上层', '厨房')).assertTrue();
      expect(isSameOrDescendantLocation('厨房/冰箱', '厨房 / 冰箱')).assertTrue();
      expect(isSameOrDescendantLocation('厨房二 / 冰箱', '厨房')).assertFalse();
      expect(isSameOrDescendantLocation('厨房', '厨房 / 冰箱')).assertFalse();
    });

    it('有效批次位置与其父位置进入筛选但旧默认位置不混入', 0, async () => {
      const items = new FakeItemRepository();
      const item = buildItem();
      item.locationPath = '旧位置';
      item.activeLocationPaths = ['书房 / 上层', '客厅 / 箱子'];
      items.items.push(item);
      const search = new ItemSearchService(items, new ItemListService(items, new ExpiryService()));
      const result = await search.getFilterOptions();
      expect(result.ok).assertTrue();
      expect(result.getData().locationPaths.indexOf('书房') >= 0).assertTrue();
      expect(result.getData().locationPaths.indexOf('书房 / 上层') >= 0).assertTrue();
      expect(result.getData().locationPaths.indexOf('客厅 / 箱子') >= 0).assertTrue();
      expect(result.getData().locationPaths.indexOf('旧位置')).assertEqual(-1);
      item.quantity = 0;
      item.activeLocationPaths = [];
      const emptyResult = await search.getFilterOptions();
      expect(emptyResult.getData().locationPaths.length).assertEqual(0);
    });

    it('消耗入口将数量与时间交给原子库存操作', 0, async () => {
      const items = new FakeItemRepository();
      items.items.push(buildItem());
      const batches = new FakeBatchRepository();
      batches.batches.push(buildDefaultBatch());
      const service = new BatchService(batches, items, () => 88);
      const consumed = await service.consume('item-1', 2);
      expect(consumed.ok).assertTrue();
      expect(batches.batches[0].quantity).assertEqual(8);
      expect(batches.lastConsumeTime).assertEqual(88);
    });

    it('保留v10迁移并在v12替换汇总与单位约束', 0, () => {
      const sql = INVENTORY_V10_MIGRATION_STATEMENTS.join('\n');
      expect(DATABASE_VERSION).assertEqual(12);
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
      const latestSql = INVENTORY_V12_MIGRATION_STATEMENTS.join('\n');
      expect(latestSql.includes('AND current_batch.quantity > 0')).assertTrue();
      expect(latestSql.includes('trg_item_after_update_sync_batch_unit')).assertTrue();
      expect(latestSql.includes('inventory quantity below outstanding loans')).assertTrue();
    });
  });
}
