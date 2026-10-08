import { createLocationId, LocationRecord } from '../model/Location';
import { LOCATION_PATH_MAX_LENGTH, normalizeLocationPath } from '../model/LocationPath';

/**
 * 手动路径随物品保存后加入位置管理；只给实际使用的完整路径记录使用时间。
 */
export function planLocationUsage(locations: LocationRecord[], input: string | undefined,
  usedAt: number): LocationRecord[] {
  const path = normalizeLocationPath(input);
  if (path === undefined || path.length > LOCATION_PATH_MAX_LENGTH ||
    locations.some((location: LocationRecord) => !location.active &&
      (path === location.path || path.startsWith(`${location.path} / `)))) {
    return [];
  }
  const segments = path.split(' / ');
  // 自由输入允许完整文本；不改变非标准分隔方式或空路径段的原有内容。
  const parts = segments.some((part: string) => part.trim().length === 0) ? [path] : segments;
  const changes: LocationRecord[] = [];
  let parentId: string | undefined = undefined;
  for (let index = 0; index < parts.length; index++) {
    const currentPath = parts.slice(0, index + 1).join(' / ');
    const existing = locations.find((location: LocationRecord) => location.path === currentPath);
    const leaf = index === parts.length - 1;
    const record: LocationRecord = {
      id: existing?.id ?? createLocationId(() => usedAt),
      name: parts[index],
      parentId: parentId,
      path: currentPath,
      active: true,
      createdAt: existing?.createdAt ?? usedAt,
      updatedAt: existing?.updatedAt ?? usedAt,
      lastUsedAt: leaf ? Math.max(existing?.lastUsedAt ?? 0, usedAt) : existing?.lastUsedAt
    };
    if (existing === undefined || leaf || existing.parentId !== parentId || existing.name !== record.name) {
      changes.push(record);
    }
    parentId = record.id;
  }
  return changes;
}
