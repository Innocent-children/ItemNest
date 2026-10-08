import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { Item, ItemUnit, PhotoState } from '../../model/Item';
import { ItemQuery } from '../../model/ItemQuery';
import { isSameOrDescendantLocation, validateInventoryReduction } from '../../service/InventoryPolicy';
import { inventoryOutstandingSql } from '../rdb/InventoryIntegritySchema';
import { BATCH_TABLE } from '../rdb/BatchSchema';
import { ITEM_TABLE } from '../rdb/ItemSchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';
import { recordLocationUsage } from './LocationDao';

export class ItemDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(item: Item): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const rowId = await store.insert(ITEM_TABLE, this.toValues(item));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存物品失败，请重试');
        }
        await recordLocationUsage(store, item.locationPath, item.updatedAt);
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '保存物品失败，请重试');
    }
  }

  async findById(itemId: string): Promise<Item | undefined> {
    const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
    predicates.equalTo('id', itemId);
    const items = await this.queryItems(predicates);
    return items.length === 0 ? undefined : items[0];
  }

  async findAll(): Promise<Item[]> {
    const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
    predicates.orderByDesc('created_at');
    return this.queryItems(predicates);
  }

  async findRecent(limit: number): Promise<Item[]> {
    const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
    predicates.orderByDesc('created_at');
    predicates.limitAs(limit);
    return this.queryItems(predicates);
  }

  async findByQuery(query: ItemQuery): Promise<Item[]> {
    const normalized = query.normalized();
    const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
    if (normalized.name.length > 0) {
      predicates.beginWrap().contains('name', normalized.name).or().contains('barcode', normalized.name).endWrap();
    }
    if (normalized.category !== undefined) {
      predicates.equalTo('category', normalized.category);
    }
    predicates.orderByDesc('created_at');
    const items = await this.queryItems(predicates);
    const location = normalized.locationPath;
    if (location === undefined) {
      return items;
    }
    return items.filter((item: Item) => {
      const paths = item.activeLocationPaths ?? (item.locationPath === undefined ? [] : [item.locationPath]);
      return paths.some((path: string) => isSameOrDescendantLocation(path, location));
    });
  }

  /**
   * 表单更新记录本次使用的位置；照片等后台更新保持原有的位置顺序。
   */
  async update(item: Item, singleBatchId?: string, rememberLocation: boolean = false): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
        if (singleBatchId !== undefined) {
          await this.validateSingleBatchUpdate(store, item, singleBatchId);
        }
        const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
        predicates.equalTo('id', item.id);
        const changedRows = await store.update(this.toUpdateValues(item), predicates);
        if (changedRows > 0 && singleBatchId !== undefined) {
          const batchPredicates = new relationalStore.RdbPredicates(BATCH_TABLE);
          batchPredicates.equalTo('id', singleBatchId).equalTo('item_id', item.id);
          await store.update({ quantity: item.quantity, expiration_date: item.expirationDate ?? null,
            location_path: item.locationPath ?? null, updated_at: item.updatedAt }, batchPredicates);
        }
        if (changedRows > 0 && rememberLocation) {
          await recordLocationUsage(store, item.locationPath, item.updatedAt);
        }
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '修改物品失败，请重试');
    }
  }

  /**
   * 单批次编辑与物品信息在同一事务保存，写入前核对批次和未归还数量。
   */
  private async validateSingleBatchUpdate(store: relationalStore.Transaction, item: Item, batchId: string): Promise<void> {
    const batches = await store.querySql('SELECT id FROM batch WHERE item_id = ?', [item.id]);
    try {
      if (batches.rowCount !== 1 || !ResultSetReader.goToNextRow(batches) ||
        ResultSetReader.readString(batches, 'id') !== batchId) {
        throw new AppError(AppErrorCode.VALIDATION, '库存明细已变化，请重新打开物品后修改');
      }
    } finally {
      ResultSetReader.close(batches);
    }
    const inventory = await store.querySql(`SELECT quantity, ${inventoryOutstandingSql('item.id')} AS borrowed_quantity
      FROM item WHERE id = ?`, [item.id]);
    try {
      if (!ResultSetReader.goToNextRow(inventory)) {
        throw new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除');
      }
      const result = validateInventoryReduction(ResultSetReader.readDouble(inventory, 'quantity') ?? 0,
        item.quantity, ResultSetReader.readDouble(inventory, 'borrowed_quantity') ?? 0);
      if (!result.ok) { throw result.getError(); }
    } finally {
      ResultSetReader.close(inventory);
    }
  }

  async deleteById(itemId: string): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
        const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
        predicates.equalTo('id', itemId);
        const changedRows = await store.delete(predicates);
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '删除物品失败，请重试');
    }
  }

  async updateDetails(item: Item): Promise<boolean> {
    return this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
      const changed = await store.update({ name: item.name, unit: item.unit, category: item.category ?? null,
        reminder_days: item.reminderDays ?? null, notes: item.notes ?? null, barcode: item.barcode ?? null,
        updated_at: item.updatedAt }, new relationalStore.RdbPredicates(ITEM_TABLE).equalTo('id', item.id));
      return changed === 1;
    });
  }

  private async queryItems(predicates: relationalStore.RdbPredicates): Promise<Item[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const items: Item[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          items.push(this.mapItem(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      await this.populateActiveLocations(store, items);
      await this.populateBorrowedQuantities(store, items);
      return items;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取物品失败，请重试');
    }
  }

  private async populateBorrowedQuantities(store: relationalStore.RdbStore, items: Item[]): Promise<void> {
    if (items.length === 0) { return; }
    const placeholders = items.map(() => '?').join(',');
    const rows = await store.querySql(`SELECT id, quantity, ${inventoryOutstandingSql('item.id')} AS borrowed_quantity
      FROM item WHERE id IN (${placeholders})`, items.map((item: Item) => item.id));
    try {
      while (ResultSetReader.goToNextRow(rows)) {
        const item = items.find((value: Item) => value.id === ResultSetReader.readString(rows, 'id'));
        if (item !== undefined) {
          item.quantity = ResultSetReader.readDouble(rows, 'quantity') ?? item.quantity;
          item.borrowedQuantity = ResultSetReader.readDouble(rows, 'borrowed_quantity') ?? 0;
        }
      }
    } finally { ResultSetReader.close(rows); }
  }

  private async populateActiveLocations(store: relationalStore.RdbStore, items: Item[]): Promise<void> {
    if (items.length === 0) {
      return;
    }
    for (let index = 0; index < items.length; index++) {
      items[index].activeLocationPaths = [];
    }
    const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
    predicates.greaterThan('quantity', 0);
    predicates.in('item_id', items.map((item: Item) => item.id));
    predicates.orderByAsc('created_at');
    const resultSet = await store.query(predicates);
    try {
      while (ResultSetReader.goToNextRow(resultSet)) {
        const itemId = this.readString(resultSet, 'item_id');
        const item = items.find((candidate: Item) => candidate.id === itemId);
        if (item === undefined) {
          continue;
        }
        const path = this.readString(resultSet, 'location_path') ?? item.locationPath;
        const paths = item.activeLocationPaths ?? [];
        if (path !== undefined && path.length > 0 && paths.indexOf(path) === -1) {
          paths.push(path);
          item.activeLocationPaths = paths;
        }
      }
    } finally {
      ResultSetReader.close(resultSet);
    }
  }

  private mapItem(resultSet: relationalStore.ResultSet): Item {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      name: this.readString(resultSet, 'name') ?? '',
      quantity: this.readDouble(resultSet, 'quantity') ?? 0,
      unit: (this.readString(resultSet, 'unit') ?? ItemUnit.PIECE) as ItemUnit,
      locationPath: this.readString(resultSet, 'location_path'),
      category: this.readString(resultSet, 'category'),
      expirationDate: this.readString(resultSet, 'expiration_date'),
      reminderDays: this.readLong(resultSet, 'reminder_days'),
      notes: this.readString(resultSet, 'notes'),
      barcode: this.readString(resultSet, 'barcode'),
      photoState: (this.readString(resultSet, 'photo_state') ?? PhotoState.NONE) as PhotoState,
      photoLocalId: this.readString(resultSet, 'photo_local_id'),
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

  private toValues(item: Item): relationalStore.ValuesBucket {
    return {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      location_path: item.locationPath ?? null,
      category: item.category ?? null,
      expiration_date: item.expirationDate ?? null,
      reminder_days: item.reminderDays ?? null,
      notes: item.notes ?? null,
      barcode: item.barcode ?? null,
      photo_state: item.photoState,
      photo_local_id: item.photoLocalId ?? null,
      created_at: item.createdAt,
      updated_at: item.updatedAt
    };
  }

  private toUpdateValues(item: Item): relationalStore.ValuesBucket {
    return {
      name: item.name,
      unit: item.unit,
      location_path: item.locationPath ?? null,
      category: item.category ?? null,
      reminder_days: item.reminderDays ?? null,
      notes: item.notes ?? null,
      barcode: item.barcode ?? null,
      photo_state: item.photoState,
      photo_local_id: item.photoLocalId ?? null,
      updated_at: item.updatedAt
    };
  }
}
