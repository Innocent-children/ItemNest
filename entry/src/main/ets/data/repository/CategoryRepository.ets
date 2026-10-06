import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { CategoryRecord } from '../../model/Category';
import { CATEGORY_TABLE } from '../rdb/CategorySchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';

export class CategoryRepository {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async renameAtomic(categoryId: string, decide: (categories: CategoryRecord[]) => Result<CategoryRecord>): Promise<Result<void>> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<Result<void>> => {
        const rows = await store.querySql('SELECT * FROM managed_category');
        const categories: CategoryRecord[] = [];
        try {
          while (ResultSetReader.goToNextRow(rows)) { categories.push(this.mapCategory(rows)); }
        } finally { ResultSetReader.close(rows); }
        const result = decide(categories);
        if (!result.ok) { return failure<void>(result.getError()); }
        const category = result.getData();
        const original = categories.find((value: CategoryRecord) => value.id === categoryId);
        if (original === undefined || category.id !== categoryId) {
          throw new AppError(AppErrorCode.NOT_FOUND, '分类不存在，请返回后重试');
        }
        await store.update(this.toValues(category), new relationalStore.RdbPredicates(CATEGORY_TABLE).equalTo('id', categoryId));
        await store.execute('UPDATE item SET category = ?, updated_at = ? WHERE category = ?',
          [category.name, category.updatedAt, original.name]);
        await store.execute('UPDATE search_history SET category = ? WHERE category = ?', [category.name, original.name]);
        return success<void>(undefined);
      });
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '分类改名失败，原有分类已保留，请重试'));
    }
  }

  async create(category: CategoryRecord): Promise<Result<CategoryRecord>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const rowId = await store.insert(CATEGORY_TABLE, this.toValues(category));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存分类失败，请重试');
        }
      });
      return success(category);
    } catch (error) {
      return failure<CategoryRecord>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存分类失败，请重试'));
    }
  }

  async listAll(): Promise<Result<CategoryRecord[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CATEGORY_TABLE);
      predicates.orderByDesc('system_preset');
      predicates.orderByAsc('name');
      return success(await this.query(predicates));
    } catch (error) {
      return failure<CategoryRecord[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取分类失败，请重试'));
    }
  }

  async setActive(categoryId: string, active: boolean, updatedAt: number): Promise<Result<void>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(CATEGORY_TABLE);
        predicates.equalTo('id', categoryId);
        const changed = await store.update({ active: active ? 1 : 0, updated_at: updatedAt }, predicates);
        if (changed === 0) {
          throw new AppError(AppErrorCode.NOT_FOUND, '分类不存在或已删除');
        }
      });
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '更新分类失败，请重试'));
    }
  }

  private async query(predicates: relationalStore.RdbPredicates): Promise<CategoryRecord[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const rows: CategoryRecord[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          rows.push(this.mapCategory(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return rows;
    } catch (error) {
      throw toAppError(error, AppErrorCode.DATABASE_READ, '读取分类失败，请重试');
    }
  }

  private mapCategory(resultSet: relationalStore.ResultSet): CategoryRecord {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      name: this.readString(resultSet, 'name') ?? '',
      active: this.readLong(resultSet, 'active') === 1,
      systemPreset: this.readLong(resultSet, 'system_preset') === 1,
      createdAt: this.readLong(resultSet, 'created_at') ?? 0,
      updatedAt: this.readLong(resultSet, 'updated_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    return ResultSetReader.readString(resultSet, column);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    return ResultSetReader.readLong(resultSet, column);
  }

  private toValues(category: CategoryRecord): relationalStore.ValuesBucket {
    return {
      id: category.id,
      name: category.name,
      active: category.active ? 1 : 0,
      system_preset: category.systemPreset ? 1 : 0,
      created_at: category.createdAt,
      updated_at: category.updatedAt
    };
  }
}
