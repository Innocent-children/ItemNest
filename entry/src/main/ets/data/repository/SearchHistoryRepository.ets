import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { SearchHistory } from '../../model/SearchHistory';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { SEARCH_HISTORY_TABLE } from '../rdb/SearchHistorySchema';
import { ResultSetReader } from '../rdb/ResultSetReader';

const MAX_HISTORY_COUNT: number = 50;

export interface SearchHistoryRepositoryPort {
  add(history: SearchHistory): Promise<Result<SearchHistory>>;
  recent(limit: number): Promise<Result<SearchHistory[]>>;
  clear(): Promise<Result<void>>;
}

export class SearchHistoryRepository implements SearchHistoryRepositoryPort {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async add(history: SearchHistory): Promise<Result<SearchHistory>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        if (history.viewedItemId !== undefined) {
          const duplicatePredicates = new relationalStore.RdbPredicates(SEARCH_HISTORY_TABLE);
          duplicatePredicates.equalTo('viewed_item_id', history.viewedItemId);
          await store.delete(duplicatePredicates);
        }
        const rowId = await store.insert(SEARCH_HISTORY_TABLE, this.toValues(history));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存搜索历史失败，请重试');
        }
        await store.execute(`
          DELETE FROM search_history
          WHERE id NOT IN (
            SELECT id FROM search_history ORDER BY created_at DESC LIMIT ${MAX_HISTORY_COUNT}
          )
        `);
      });
      return success(history);
    } catch (error) {
      return failure<SearchHistory>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存搜索历史失败，请重试'));
    }
  }

  async recent(limit: number): Promise<Result<SearchHistory[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(SEARCH_HISTORY_TABLE);
      predicates.orderByDesc('created_at');
      predicates.limitAs(Math.max(0, Math.min(limit, MAX_HISTORY_COUNT)));
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const rows: SearchHistory[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          rows.push(this.mapHistory(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return success(rows);
    } catch (error) {
      return failure<SearchHistory[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取搜索历史失败，请重试'));
    }
  }

  async clear(): Promise<Result<void>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(SEARCH_HISTORY_TABLE);
        await store.delete(predicates);
      });
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '清除搜索历史失败，请重试'));
    }
  }

  private mapHistory(resultSet: relationalStore.ResultSet): SearchHistory {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      queryText: this.readString(resultSet, 'query_text'),
      locationPath: this.readString(resultSet, 'location_path'),
      category: this.readString(resultSet, 'category'),
      viewedItemId: this.readString(resultSet, 'viewed_item_id'),
      createdAt: this.readLong(resultSet, 'created_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    return ResultSetReader.readString(resultSet, column);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    return ResultSetReader.readLong(resultSet, column);
  }

  private toValues(history: SearchHistory): relationalStore.ValuesBucket {
    return {
      id: history.id,
      query_text: history.queryText ?? null,
      location_path: history.locationPath ?? null,
      category: history.category ?? null,
      viewed_item_id: history.viewedItemId ?? null,
      created_at: history.createdAt
    };
  }
}
