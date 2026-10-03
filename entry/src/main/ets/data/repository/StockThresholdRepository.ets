import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { StockThreshold } from '../../model/StockThreshold';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { STOCK_THRESHOLD_TABLE } from '../rdb/StockThresholdSchema';
import { ResultSetReader } from '../rdb/ResultSetReader';

export interface StockThresholdRepositoryPort {
  save(threshold: StockThreshold): Promise<Result<StockThreshold>>;
  getByItemId(itemId: string): Promise<Result<StockThreshold | undefined>>;
  listEnabled(): Promise<Result<StockThreshold[]>>;
}

export class StockThresholdRepository implements StockThresholdRepositoryPort {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async save(threshold: StockThreshold): Promise<Result<StockThreshold>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const existing = await this.findByItemIdInStore(store, threshold.itemId);
        if (existing === undefined) {
          const rowId = await store.insert(STOCK_THRESHOLD_TABLE, this.toValues(threshold));
          if (rowId < 0) {
            throw new AppError(AppErrorCode.DATABASE_WRITE, '保存低库存阈值失败，请重试');
          }
          return;
        }
        const predicates = new relationalStore.RdbPredicates(STOCK_THRESHOLD_TABLE);
        predicates.equalTo('item_id', threshold.itemId);
        await store.update(this.toValues(threshold), predicates);
      });
      return success(threshold);
    } catch (error) {
      return failure<StockThreshold>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存低库存阈值失败，请重试'));
    }
  }

  async getByItemId(itemId: string): Promise<Result<StockThreshold | undefined>> {
    try {
      return success(await this.findByItemIdRaw(itemId));
    } catch (error) {
      return failure<StockThreshold | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取低库存阈值失败，请重试'));
    }
  }

  async listEnabled(): Promise<Result<StockThreshold[]>> {
    return this.listRows(true);
  }

  async listAll(): Promise<Result<StockThreshold[]>> {
    return this.listRows(false);
  }

  private async listRows(enabledOnly: boolean): Promise<Result<StockThreshold[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(STOCK_THRESHOLD_TABLE);
      if (enabledOnly) {
        predicates.equalTo('enabled', 1);
      }
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const rows: StockThreshold[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          rows.push(this.mapThreshold(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return success(rows);
    } catch (error) {
      return failure<StockThreshold[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取低库存阈值失败，请重试'));
    }
  }

  private async findByItemIdRaw(itemId: string): Promise<StockThreshold | undefined> {
    try {
      const predicates = new relationalStore.RdbPredicates(STOCK_THRESHOLD_TABLE);
      predicates.equalTo('item_id', itemId);
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      try {
        if (ResultSetReader.goToNextRow(resultSet)) {
          return this.mapThreshold(resultSet);
        }
        return undefined;
      } finally {
        ResultSetReader.close(resultSet);
      }
    } catch (error) {
      throw toAppError(error, AppErrorCode.DATABASE_READ, '读取低库存阈值失败，请重试');
    }
  }

  private async findByItemIdInStore(store: relationalStore.Transaction, itemId: string): Promise<StockThreshold | undefined> {
    try {
      const predicates = new relationalStore.RdbPredicates(STOCK_THRESHOLD_TABLE);
      predicates.equalTo('item_id', itemId);
      const resultSet = await store.query(predicates);
      try {
        if (ResultSetReader.goToNextRow(resultSet)) {
          return this.mapThreshold(resultSet);
        }
        return undefined;
      } finally {
        ResultSetReader.close(resultSet);
      }
    } catch (error) {
      throw toAppError(error, AppErrorCode.DATABASE_READ, '读取低库存阈值失败，请重试');
    }
  }

  private mapThreshold(resultSet: relationalStore.ResultSet): StockThreshold {
    return {
      itemId: ResultSetReader.readString(resultSet, 'item_id') ?? '',
      threshold: ResultSetReader.readDouble(resultSet, 'threshold') ?? 0,
      enabled: ResultSetReader.readLong(resultSet, 'enabled') === 1,
      updatedAt: ResultSetReader.readLong(resultSet, 'updated_at') ?? 0
    };
  }

  private toValues(threshold: StockThreshold): relationalStore.ValuesBucket {
    return {
      item_id: threshold.itemId,
      threshold: threshold.threshold,
      enabled: threshold.enabled ? 1 : 0,
      updated_at: threshold.updatedAt
    };
  }
}
