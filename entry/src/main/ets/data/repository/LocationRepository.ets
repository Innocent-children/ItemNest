import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { LocationRecord, LocationRenamePlan } from '../../model/Location';
import { LOCATION_TABLE } from '../rdb/LocationSchema';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';
import { readLocationRecord } from '../dao/LocationDao';

export interface LocationRepositoryPort {
  renameAtomic(decide: (locations: LocationRecord[], referencedPaths: string[]) => Result<LocationRenamePlan>): Promise<Result<void>>;
  create(location: LocationRecord): Promise<Result<LocationRecord>>;
  listAll(): Promise<Result<LocationRecord[]>>;
  getById(locationId: string): Promise<Result<LocationRecord | undefined>>;
  setActive(locationId: string, active: boolean, updatedAt: number): Promise<Result<void>>;
}

export class LocationRepository implements LocationRepositoryPort {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  /**
   * 在同一事务内更新位置树和保存了路径的物品、库存、搜索记录。
   */
  async renameAtomic(decide: (locations: LocationRecord[], referencedPaths: string[]) => Result<LocationRenamePlan>): Promise<Result<void>> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<Result<void>> => {
        const rows = await store.querySql('SELECT * FROM managed_location');
        const locations: LocationRecord[] = [];
        try {
          while (ResultSetReader.goToNextRow(rows)) { locations.push(readLocationRecord(rows)); }
        } finally { ResultSetReader.close(rows); }
        const references = await store.querySql('SELECT location_path FROM item UNION SELECT location_path FROM batch UNION SELECT location_path FROM search_history');
        const paths: string[] = [];
        try {
          while (ResultSetReader.goToNextRow(references)) {
            const path = ResultSetReader.readString(references, 'location_path');
            if (path !== undefined) { paths.push(path); }
          }
        } finally { ResultSetReader.close(references); }
        const result = decide(locations, paths);
        if (!result.ok) { return failure<void>(result.getError()); }
        const plan = result.getData();
        for (const location of plan.locations) {
          await store.update(this.toValues(location), new relationalStore.RdbPredicates(LOCATION_TABLE).equalTo('id', location.id));
        }
        for (const table of ['item', 'batch', 'search_history']) {
          const timestamp = table === 'search_history' ? '' : ', updated_at = ?';
          const args: relationalStore.ValueType[] = [plan.newPath, plan.oldPath];
          if (table !== 'search_history') { args.push(plan.updatedAt); }
          args.push(plan.oldPath, plan.oldPath);
          await store.execute(`UPDATE ${table} SET location_path = ? || substr(location_path, length(?) + 1)${timestamp} ` +
            "WHERE location_path = ? OR instr(location_path, ? || ' / ') = 1", args);
        }
        return success<void>(undefined);
      });
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '位置改名失败，原有位置已保留，请重试'));
    }
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
          locations.push(readLocationRecord(resultSet));
        }
      } finally {
        ResultSetReader.close(resultSet);
      }
      return locations;
    } catch (error) {
      throw toAppError(error, AppErrorCode.DATABASE_READ, '读取位置失败，请重试');
    }
  }

  private toValues(location: LocationRecord): relationalStore.ValuesBucket {
    return {
      id: location.id,
      name: location.name,
      parent_id: location.parentId ?? null,
      path: location.path,
      active: location.active ? 1 : 0,
      created_at: location.createdAt,
      updated_at: location.updatedAt,
      last_used_at: location.lastUsedAt ?? null
    };
  }
}
