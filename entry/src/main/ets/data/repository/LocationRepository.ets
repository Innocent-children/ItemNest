import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { LocationRecord } from '../../model/Location';
import { LOCATION_TABLE } from '../rdb/LocationSchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';

export class LocationRepository {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(location: LocationRecord): Promise<Result<LocationRecord>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const rowId = await store.insert(LOCATION_TABLE, this.toValues(location));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存位置失败，请重试');
        }
      });
      return success(location);
    } catch (error) {
      return failure<LocationRecord>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存位置失败，请重试'));
    }
  }

  async listAll(): Promise<Result<LocationRecord[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(LOCATION_TABLE);
      predicates.orderByAsc('path');
      return success(await this.query(predicates));
    } catch (error) {
      return failure<LocationRecord[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取位置失败，请重试'));
    }
  }

  async getById(locationId: string): Promise<Result<LocationRecord | undefined>> {
    try {
      const predicates = new relationalStore.RdbPredicates(LOCATION_TABLE);
      predicates.equalTo('id', locationId);
      const rows = await this.query(predicates);
      return success(rows.length === 0 ? undefined : rows[0]);
    } catch (error) {
      return failure<LocationRecord | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取位置失败，请重试'));
    }
  }

  async setActive(locationId: string, active: boolean, updatedAt: number): Promise<Result<void>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(LOCATION_TABLE);
        predicates.equalTo('id', locationId);
        const changed = await store.update({ active: active ? 1 : 0, updated_at: updatedAt }, predicates);
        if (changed === 0) {
          throw new AppError(AppErrorCode.NOT_FOUND, '位置不存在或已删除');
        }
      });
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '更新位置失败，请重试'));
    }
  }

  private async query(predicates: relationalStore.RdbPredicates): Promise<LocationRecord[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const locations: LocationRecord[] = [];
      try {
        while (ResultSetReader.goToNextRow(resultSet)) {
          locations.push(this.mapLocation(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return locations;
    } catch (error) {
      throw toAppError(error, AppErrorCode.DATABASE_READ, '读取位置失败，请重试');
    }
  }

  private mapLocation(resultSet: relationalStore.ResultSet): LocationRecord {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      name: this.readString(resultSet, 'name') ?? '',
      parentId: this.readString(resultSet, 'parent_id'),
      path: this.readString(resultSet, 'path') ?? '',
      active: this.readLong(resultSet, 'active') === 1,
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

  private toValues(location: LocationRecord): relationalStore.ValuesBucket {
    return {
      id: location.id,
      name: location.name,
      parent_id: location.parentId ?? null,
      path: location.path,
      active: location.active ? 1 : 0,
      created_at: location.createdAt,
      updated_at: location.updatedAt
    };
  }
}
