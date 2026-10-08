import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { LocationRecord } from '../../model/Location';
import { normalizeLocationPath } from '../../model/LocationPath';
import { planLocationUsage } from '../../service/LocationUsagePolicy';
import { ResultSetReader } from '../rdb/ResultSetReader';

export function readLocationRecord(rows: relationalStore.ResultSet): LocationRecord {
  return {
    id: ResultSetReader.readString(rows, 'id') ?? '',
    name: ResultSetReader.readString(rows, 'name') ?? '',
    parentId: ResultSetReader.readString(rows, 'parent_id'),
    path: ResultSetReader.readString(rows, 'path') ?? '',
    active: ResultSetReader.readLong(rows, 'active') === 1,
    createdAt: ResultSetReader.readLong(rows, 'created_at') ?? 0,
    updatedAt: ResultSetReader.readLong(rows, 'updated_at') ?? 0,
    lastUsedAt: ResultSetReader.readLong(rows, 'last_used_at')
  };
}

/**
 * 使用调用方的事务保存位置，物品或批次写入失败时一起回滚。
 */
export async function recordLocationUsage(store: relationalStore.Transaction, path: string | undefined,
  usedAt: number): Promise<void> {
  if (normalizeLocationPath(path) === undefined) { return; }
  const rows = await store.querySql('SELECT * FROM managed_location');
  const locations: LocationRecord[] = [];
  try {
    while (ResultSetReader.goToNextRow(rows)) { locations.push(readLocationRecord(rows)); }
  } finally { ResultSetReader.close(rows); }
  for (const record of planLocationUsage(locations, path, usedAt)) {
    const values: relationalStore.ValuesBucket = {
      id: record.id, name: record.name, parent_id: record.parentId ?? null, path: record.path,
      active: record.active ? 1 : 0, created_at: record.createdAt, updated_at: record.updatedAt,
      last_used_at: record.lastUsedAt ?? null
    };
    if (locations.some((location: LocationRecord) => location.id === record.id)) {
      await store.update(values, new relationalStore.RdbPredicates('managed_location').equalTo('id', record.id));
    } else {
      const rowId = await store.insert('managed_location', values);
      if (rowId < 0) { throw new AppError(AppErrorCode.DATABASE_WRITE, '保存历史位置失败，请重试'); }
    }
  }
}

interface ReferencedLocation {
  path: string;
  usedAt: number;
}

/**
 * 升级或恢复后补入已有物品、批次的位置，保留已经记录的实际使用时间。
 */
export async function backfillLocationUsage(store: relationalStore.Transaction): Promise<void> {
  const rows = await store.querySql(`SELECT location_path, MAX(updated_at) AS used_at FROM (
    SELECT location_path, updated_at FROM item UNION ALL SELECT location_path, updated_at FROM batch
  ) WHERE location_path IS NOT NULL AND trim(location_path) <> ''
    AND NOT EXISTS (SELECT 1 FROM managed_location
      WHERE managed_location.path = trim(location_path) AND last_used_at IS NOT NULL)
  GROUP BY location_path ORDER BY used_at`);
  const references: ReferencedLocation[] = [];
  try {
    while (ResultSetReader.goToNextRow(rows)) {
      references.push({ path: ResultSetReader.readString(rows, 'location_path') ?? '',
        usedAt: ResultSetReader.readLong(rows, 'used_at') ?? 0 });
    }
  } finally { ResultSetReader.close(rows); }
  for (const reference of references) { await recordLocationUsage(store, reference.path, reference.usedAt); }
}
