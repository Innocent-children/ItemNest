import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { Item, ItemUnit, PhotoState } from '../../model/Item';
import { ItemQuery } from '../../model/ItemQuery';
import { ITEM_TABLE } from '../rdb/ItemSchema';
import { RdbDatabase } from '../rdb/RdbDatabase';

export class ItemDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(item: Item): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const rowId = await store.insert(ITEM_TABLE, this.toValues(item));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存物品失败，请重试');
        }
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
      predicates.contains('name', normalized.name);
    }
    if (normalized.locationPath !== undefined) {
      predicates.equalTo('location_path', normalized.locationPath);
    }
    if (normalized.category !== undefined) {
      predicates.equalTo('category', normalized.category);
    }
    predicates.orderByDesc('created_at');
    return this.queryItems(predicates);
  }

  async update(item: Item): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.RdbStore): Promise<boolean> => {
        const predicates = new relationalStore.RdbPredicates(ITEM_TABLE);
        predicates.equalTo('id', item.id);
        const changedRows = await store.update(this.toUpdateValues(item), predicates);
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '修改物品失败，请重试');
    }
  }

  async deleteById(itemId: string): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.RdbStore): Promise<boolean> => {
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

  private async queryItems(predicates: relationalStore.RdbPredicates): Promise<Item[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const items: Item[] = [];
      try {
        while (resultSet.goToNextRow()) {
          items.push(this.mapItem(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return items;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取物品失败，请重试');
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
      photoState: (this.readString(resultSet, 'photo_state') ?? PhotoState.NONE) as PhotoState,
      photoLocalId: this.readString(resultSet, 'photo_local_id'),
      createdAt: this.readLong(resultSet, 'created_at') ?? 0,
      updatedAt: this.readLong(resultSet, 'updated_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readDouble(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getDouble(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
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
      photo_state: item.photoState,
      photo_local_id: item.photoLocalId ?? null,
      created_at: item.createdAt,
      updated_at: item.updatedAt
    };
  }

  private toUpdateValues(item: Item): relationalStore.ValuesBucket {
    return {
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      location_path: item.locationPath ?? null,
      category: item.category ?? null,
      expiration_date: item.expirationDate ?? null,
      reminder_days: item.reminderDays ?? null,
      notes: item.notes ?? null,
      photo_state: item.photoState,
      photo_local_id: item.photoLocalId ?? null,
      updated_at: item.updatedAt
    };
  }
}
