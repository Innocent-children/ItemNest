import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { Batch, ConsumptionReceipt, ConsumedStock } from '../../model/Batch';
import { ItemUnit } from '../../model/Item';
import { createTraceEventId, TraceEventType } from '../../model/TraceEvent';
import { planConsumption, validateConsumptionUndo, validateInventoryReduction } from '../../service/InventoryPolicy';
import { BATCH_TABLE } from '../rdb/BatchSchema';
import { inventoryOutstandingSql } from '../rdb/InventoryIntegritySchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';
import { recordLocationUsage } from './LocationDao';

interface InventorySnapshot {
  quantity: number;
  borrowedQuantity: number;
  unit: ItemUnit;
}

export class BatchDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(batch: Batch): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const inventory = await this.readInventory(store, batch.itemId);
        this.validateUnit(batch.unit, inventory.unit);
        this.validateReduction(inventory.quantity, inventory.quantity + batch.quantity, inventory.borrowedQuantity);
        const rowId = await store.insert(BATCH_TABLE, this.toValues(batch));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存批次失败，请重试');
        }
        await recordLocationUsage(store, batch.locationPath, batch.updatedAt);
        await this.appendStockEvent(store, batch, TraceEventType.STOCK_ADD, batch.quantity,
          `补入到 ${batch.locationPath || '未填写位置'}`, batch.createdAt);
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '保存批次失败，请重试');
    }
  }

  async findById(batchId: string): Promise<Batch | undefined> {
    const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
    predicates.equalTo('id', batchId);
    const batches = await this.queryBatches(predicates);
    return batches.length === 0 ? undefined : batches[0];
  }

  async findByItemId(itemId: string): Promise<Batch[]> {
    return this.queryBatches(this.itemPredicates(itemId));
  }

  async findAll(): Promise<Batch[]> {
    const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
    predicates.orderByDesc('created_at');
    return this.queryBatches(predicates);
  }

  async update(batch: Batch): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
        const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
        predicates.equalTo('id', batch.id);
        const existing = await this.readBatches(await store.query(predicates));
        if (existing.length === 0) {
          return false;
        }
        const inventory = await this.readInventory(store, existing[0].itemId);
        this.validateUnit(batch.unit, inventory.unit);
        const nextQuantity = Math.round((inventory.quantity - existing[0].quantity + batch.quantity) * 100) / 100;
        this.validateReduction(inventory.quantity, nextQuantity, inventory.borrowedQuantity);
        const changedRows = await store.update(this.toUpdateValues(batch), predicates);
        if (changedRows > 0) {
          await recordLocationUsage(store, batch.locationPath, batch.updatedAt);
          await this.recordStockChanges(store, existing[0], batch.quantity, batch.locationPath, batch.updatedAt);
        }
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '修改批次失败，请重试');
    }
  }

  // 最后一个批次清零并保留历史；多个批次时才删除所选批次。
  async deleteById(batchId: string): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
        const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
        predicates.equalTo('id', batchId);
        const existing = await this.readBatches(await store.query(predicates));
        if (existing.length === 0) {
          return false;
        }
        const batch = existing[0];
        const inventory = await this.readInventory(store, batch.itemId);
        this.validateReduction(inventory.quantity, Math.round((inventory.quantity - batch.quantity) * 100) / 100,
          inventory.borrowedQuantity);
        const itemBatches = await this.readBatches(await store.query(this.itemPredicates(batch.itemId)));
        if (itemBatches.length <= 1) {
          const changedRows = await store.update({ quantity: 0, updated_at: Date.now() }, predicates);
          return changedRows > 0;
        }
        return (await store.delete(predicates)) > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '删除批次失败，请重试');
    }
  }

  async consume(itemId: string, quantity: number, batchId: string | undefined, now: number, expectedUnit?: ItemUnit): Promise<ConsumptionReceipt> {
    return this.database.transaction(async (store: relationalStore.Transaction): Promise<ConsumptionReceipt> => {
      const inventory = await this.readInventory(store, itemId);
      if (expectedUnit !== undefined) { this.validateUnit(expectedUnit, inventory.unit); }
      const batches = await this.readBatches(await store.query(this.itemPredicates(itemId)));
      const planned = planConsumption(batches, quantity, inventory.borrowedQuantity, batchId);
      if (!planned.ok) {
        throw planned.getError();
      }
      const allocations = planned.getData();
      const receipt: ConsumptionReceipt = { eventId: createTraceEventId(() => now), itemId: itemId,
        quantity: quantity, unit: inventory.unit, createdAt: now,
        availableBefore: Math.max(0, Math.round((inventory.quantity - inventory.borrowedQuantity) * 100) / 100),
        availableAfter: Math.max(0, Math.round((inventory.quantity - inventory.borrowedQuantity - quantity) * 100) / 100), stocks: allocations.map((allocation): ConsumedStock => ({
          batchId: allocation.batch.id, beforeQuantity: allocation.batch.quantity, afterQuantity: allocation.remainingQuantity
        })) };
      for (let index = 0; index < allocations.length; index++) {
        const allocation = allocations[index];
        const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
        predicates.equalTo('id', allocation.batch.id);
        if (await store.update({ quantity: allocation.remainingQuantity, updated_at: now }, predicates) !== 1) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '库存已变化，请重试');
        }
      }
      const rowId = await store.insert('trace_event', {
        id: receipt.eventId,
        item_id: itemId,
        batch_id: allocations.length === 1 ? allocations[0].batch.id : null,
        type: 'CONSUME',
        quantity: quantity,
        counterpart: null,
        note: batchId === undefined ? '记录消耗，优先扣减最早到期的现存批次' : '记录所选批次的消耗',
        created_at: now,
        voided_at: null,
        return_allocations_json: null,
        legacy_allocated: 0
      });
      if (rowId < 0) {
        throw new AppError(AppErrorCode.DATABASE_WRITE, '保存消耗记录失败，请重试');
      }
      return receipt;
    });
  }

  async undoConsumption(receipt: ConsumptionReceipt, now: number): Promise<void> {
    await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
      const rows = await store.querySql('SELECT item_id,type,quantity,created_at,voided_at FROM trace_event WHERE id = ?', [receipt.eventId]);
      try {
        if (!ResultSetReader.goToFirstRow(rows) || ResultSetReader.readString(rows, 'item_id') !== receipt.itemId ||
          ResultSetReader.readString(rows, 'type') !== 'CONSUME' || ResultSetReader.readLong(rows, 'voided_at') !== undefined ||
          ResultSetReader.readDouble(rows, 'quantity') !== receipt.quantity || ResultSetReader.readLong(rows, 'created_at') !== receipt.createdAt) {
          throw new AppError(AppErrorCode.VALIDATION, '这次消耗已撤销或记录已变化，请重新查看库存');
        }
      } finally { ResultSetReader.close(rows); }
      const batches = await this.readBatches(await store.query(this.itemPredicates(receipt.itemId)));
      const validated = validateConsumptionUndo(batches, receipt);
      if (!validated.ok) { throw validated.getError(); }
      for (const stock of receipt.stocks) {
        const changed = await store.update({ quantity: stock.beforeQuantity, updated_at: now },
          new relationalStore.RdbPredicates(BATCH_TABLE).equalTo('id', stock.batchId).equalTo('item_id', receipt.itemId));
        if (changed !== 1) { throw new AppError(AppErrorCode.DATABASE_WRITE, '恢复库存失败，请重试'); }
      }
      if (await store.update({ voided_at: now }, new relationalStore.RdbPredicates('trace_event').equalTo('id', receipt.eventId)) !== 1) {
        throw new AppError(AppErrorCode.DATABASE_WRITE, '撤销消耗失败，请重试');
      }
    });
  }

  async changeStock(batchId: string, quantity: number | undefined, locationPath: string | undefined,
    changeLocation: boolean, now: number, expectedUnit?: ItemUnit): Promise<void> {
    await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
      const predicates = new relationalStore.RdbPredicates(BATCH_TABLE).equalTo('id', batchId);
      const batches = await this.readBatches(await store.query(predicates));
      if (batches.length === 0) { throw new AppError(AppErrorCode.NOT_FOUND, '这份库存已删除，请重新选择'); }
      const batch = batches[0];
      const inventory = await this.readInventory(store, batch.itemId);
      const values: relationalStore.ValuesBucket = { updated_at: now };
      if (quantity !== undefined) {
        if (expectedUnit !== undefined) { this.validateUnit(expectedUnit, inventory.unit); }
        this.validateReduction(inventory.quantity, Math.round((inventory.quantity - batch.quantity + quantity) * 100) / 100, inventory.borrowedQuantity);
        values.quantity = quantity;
      }
      if (changeLocation) { values.location_path = locationPath ?? null; }
      if (await store.update(values, predicates) !== 1) { throw new AppError(AppErrorCode.DATABASE_WRITE, '保存库存失败，请重试'); }
      if (changeLocation) { await recordLocationUsage(store, locationPath, now); }
      if (changeLocation) {
        await store.execute('UPDATE item SET location_path = ? WHERE id = ? AND (SELECT COUNT(*) FROM batch WHERE item_id = ?) = 1',
          [locationPath ?? null, batch.itemId, batch.itemId]);
      }
      await this.recordStockChanges(store, batch, quantity ?? batch.quantity,
        changeLocation ? locationPath : batch.locationPath, now);
    });
  }

  private async recordStockChanges(store: relationalStore.Transaction, before: Batch, quantity: number,
    locationPath: string | undefined, now: number): Promise<void> {
    if (before.quantity !== quantity) {
      await this.appendStockEvent(store, before, TraceEventType.QUANTITY_ADJUST, quantity,
        `从 ${before.quantity}${before.unit} 调整为 ${quantity}${before.unit}`, now);
    }
    if ((before.locationPath ?? '') !== (locationPath ?? '')) {
      await this.appendStockEvent(store, before, TraceEventType.MOVE, quantity,
        `从 ${before.locationPath || '未填写位置'} 移到 ${locationPath || '未填写位置'}`, now);
    }
  }

  private async appendStockEvent(store: relationalStore.Transaction, batch: Batch, type: TraceEventType,
    quantity: number, note: string, now: number): Promise<void> {
    const rowId = await store.insert('trace_event', {
      id: createTraceEventId(() => now), item_id: batch.itemId, batch_id: batch.id,
      type: type, quantity: quantity, note: note, created_at: now, legacy_allocated: 0
    });
    if (rowId < 0) { throw new AppError(AppErrorCode.DATABASE_WRITE, '保存使用记录失败，请重试'); }
  }

  private itemPredicates(itemId: string): relationalStore.RdbPredicates {
    const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
    predicates.equalTo('item_id', itemId);
    predicates.orderByAsc('expiration_date');
    predicates.orderByAsc('created_at');
    return predicates;
  }

  private validateUnit(unit: ItemUnit, expectedUnit: ItemUnit): void {
    if (unit !== expectedUnit) {
      throw new AppError(AppErrorCode.VALIDATION, `物品单位已变更为 ${expectedUnit}，请重新打开批次后保存`);
    }
  }

  private validateReduction(currentQuantity: number, nextQuantity: number, borrowedQuantity: number): void {
    const validated = validateInventoryReduction(currentQuantity, nextQuantity, borrowedQuantity);
    if (!validated.ok) {
      throw validated.getError();
    }
  }

  private async readInventory(store: relationalStore.Transaction, itemId: string): Promise<InventorySnapshot> {
    const resultSet = await store.querySql(`SELECT quantity, unit, ${inventoryOutstandingSql('item.id')} AS borrowed_quantity
      FROM item WHERE id = ?`, [itemId]);
    try {
      if (!ResultSetReader.goToFirstRow(resultSet)) {
        throw new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除');
      }
      return {
        quantity: ResultSetReader.readDouble(resultSet, 'quantity') ?? 0,
        borrowedQuantity: ResultSetReader.readDouble(resultSet, 'borrowed_quantity') ?? 0,
        unit: (ResultSetReader.readString(resultSet, 'unit') ?? ItemUnit.PIECE) as ItemUnit
      };
    } finally {
      ResultSetReader.close(resultSet);
    }
  }

  private async queryBatches(predicates: relationalStore.RdbPredicates): Promise<Batch[]> {
    try {
      const store = await this.database.requireStore();
      return this.readBatches(await store.query(predicates));
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取批次失败，请重试');
    }
  }

  private async readBatches(resultSet: relationalStore.ResultSet): Promise<Batch[]> {
    const batches: Batch[] = [];
    try {
      while (ResultSetReader.goToNextRow(resultSet)) {
        batches.push(this.mapBatch(resultSet));
      }
    } finally {
      ResultSetReader.close(resultSet);
    }
    return batches;
  }

  private mapBatch(resultSet: relationalStore.ResultSet): Batch {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      itemId: this.readString(resultSet, 'item_id') ?? '',
      quantity: this.readDouble(resultSet, 'quantity') ?? 0,
      unit: (this.readString(resultSet, 'unit') ?? ItemUnit.PIECE) as ItemUnit,
      expirationDate: this.readString(resultSet, 'expiration_date'),
      locationPath: this.readString(resultSet, 'location_path'),
      notes: this.readString(resultSet, 'notes'),
      createdAt: this.readLong(resultSet, 'created_at') ?? 0,
      updatedAt: this.readLong(resultSet, 'updated_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    return ResultSetReader.readString(resultSet, column);
  }

  private readDouble(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    return ResultSetReader.readDouble(resultSet, column);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    return ResultSetReader.readLong(resultSet, column);
  }

  private toValues(batch: Batch): relationalStore.ValuesBucket {
    return {
      id: batch.id,
      item_id: batch.itemId,
      quantity: batch.quantity,
      unit: batch.unit,
      expiration_date: batch.expirationDate ?? null,
      location_path: batch.locationPath ?? null,
      notes: batch.notes ?? null,
      created_at: batch.createdAt,
      updated_at: batch.updatedAt
    };
  }

  private toUpdateValues(batch: Batch): relationalStore.ValuesBucket {
    return {
      quantity: batch.quantity,
      unit: batch.unit,
      expiration_date: batch.expirationDate ?? null,
      location_path: batch.locationPath ?? null,
      notes: batch.notes ?? null,
      updated_at: batch.updatedAt
    };
  }
}
