import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { Category } from '../../model/Category';
import { SearchHistory } from '../../model/SearchHistory';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { SEARCH_HISTORY_TABLE } from '../rdb/SearchHistorySchema';

export class SearchHistoryRepository {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async add(history: SearchHistory): Promise<Result<SearchHistory>> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const rowId = await store.insert(SEARCH_HISTORY_TABLE, this.toValues(history));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存搜索历史失败，请重试');
        }
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
      predicates.limitAs(limit);
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const rows: SearchHistory[] = [];
      try {
        while (resultSet.goToNextRow()) {
          rows.push(this.mapHistory(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return success(rows);
    } catch (error) {
      return failure<SearchHistory[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取搜索历史失败，请重试'));
    }
  }

  async clear(): Promise<Result<void>> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
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
      category: this.readString(resultSet, 'category') as Category | undefined,
      viewedItemId: this.readString(resultSet, 'viewed_item_id'),
      createdAt: this.readLong(resultSet, 'created_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
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
