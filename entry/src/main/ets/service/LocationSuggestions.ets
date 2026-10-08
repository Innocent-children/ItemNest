import { LocationRecord } from '../model/Location';

const PRESET_PATHS: string[] = ['客厅', '卧室', '厨房', '卫生间', '书房', '阳台', '玄关', '储物间'];

export interface LocationSuggestions {
  recentPaths: string[];
  savedPaths: string[];
  presetPaths: string[];
  hasHistory: boolean;
}

export function buildLocationSuggestions(locations: LocationRecord[], input: string,
  limit: number = 6): LocationSuggestions {
  const query = input.trim().toLocaleLowerCase();
  const disabled = locations.filter((location: LocationRecord) => !location.active);
  const available = locations.filter((location: LocationRecord) => location.active &&
    !disabled.some((root: LocationRecord) => location.path === root.path || location.path.startsWith(`${root.path} / `)));
  const seen = new Set<string>();
  const matching = available.slice().sort((left: LocationRecord, right: LocationRecord) =>
    (right.lastUsedAt ?? -1) - (left.lastUsedAt ?? -1) || left.path.localeCompare(right.path))
    .filter((location: LocationRecord) => {
      const path = location.path.trim();
      if (path.length === 0 || seen.has(path)) { return false; }
      seen.add(path);
      return path.toLocaleLowerCase().includes(query);
    });
  const recentPaths = matching.filter((location: LocationRecord) => location.lastUsedAt !== undefined)
    .slice(0, limit).map((location: LocationRecord) => location.path);
  const savedPaths = matching.filter((location: LocationRecord) => location.lastUsedAt === undefined)
    .slice(0, Math.max(0, limit - recentPaths.length)).map((location: LocationRecord) => location.path);
  const presetPaths = PRESET_PATHS.filter((path: string) => path.toLocaleLowerCase().includes(query) &&
    !seen.has(path) && !disabled.some((location: LocationRecord) => path === location.path || path.startsWith(`${location.path} / `)));
  return { recentPaths: recentPaths, savedPaths: savedPaths, presetPaths: presetPaths,
    hasHistory: available.some((location: LocationRecord) => location.lastUsedAt !== undefined) };
}
