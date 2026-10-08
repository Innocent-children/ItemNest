import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { Batch } from '../../model/Batch';
import { ItemUnit } from '../../model/Item';
import { createTraceEventId } from '../../model/TraceEvent';
import { planConsumption, validateInventoryReduction } from '../../service/InventoryPolicy';
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
        if (changedRows > 0) { await recordLocationUsage(store, batch.locationPath, batch.updatedAt); }
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

  async consume(itemId: string, quantity: number, batchId: string | undefined, now: number): Promise<void> {
    await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
      const inventory = await this.readInventory(store, itemId);
      const batches = await this.readBatches(await store.query(this.itemPredicates(itemId)));
      const planned = planConsumption(batches, quantity, inventory.borrowedQuantity, batchId);
      if (!planned.ok) {
        throw planned.getError();
      }
      const allocations = planned.getData();
      for (let index = 0; index < allocations.length; index++) {
        const allocation = allocations[index];
        const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
        predicates.equalTo('id', allocation.batch.id);
        await store.update({ quantity: allocation.remainingQuantity, updated_at: now }, predicates);
      }
      const rowId = await store.insert('trace_event', {
        id: createTraceEventId(() => now),
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
    });
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
