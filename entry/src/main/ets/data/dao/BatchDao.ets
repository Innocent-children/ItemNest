import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { Batch } from '../../model/Batch';
import { ItemUnit } from '../../model/Item';
import { BATCH_TABLE } from '../rdb/BatchSchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';

export class BatchDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(batch: Batch): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const rowId = await store.insert(BATCH_TABLE, this.toValues(batch));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存批次失败，请重试');
        }
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
    const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
    predicates.equalTo('item_id', itemId);
    predicates.orderByAsc('expiration_date');
    predicates.orderByAsc('created_at');
    return this.queryBatches(predicates);
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
        const changedRows = await store.update(this.toUpdateValues(batch), predicates);
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '修改批次失败，请重试');
    }
  }

  async deleteById(batchId: string): Promise<boolean> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<boolean> => {
        const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
        predicates.equalTo('id', batchId);
        const changedRows = await store.delete(predicates);
        return changedRows > 0;
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '删除批次失败，请重试');
    }
  }

  private async queryBatches(predicates: relationalStore.RdbPredicates): Promise<Batch[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const batches: Batch[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          batches.push(this.mapBatch(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return batches;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取批次失败，请重试');
    }
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
