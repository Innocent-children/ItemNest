import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { CategoryRecord } from '../../model/Category';
import { CATEGORY_TABLE } from '../rdb/CategorySchema';
import { RdbDatabase } from '../rdb/RdbDatabase';

export class CategoryRepository {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(category: CategoryRecord): Promise<Result<CategoryRecord>> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
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
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
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
    const store = await this.database.requireStore();
    const resultSet = await store.query(predicates);
    const rows: CategoryRecord[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push(this.mapCategory(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return rows;
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
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
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
