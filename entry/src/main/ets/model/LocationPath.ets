export const LOCATION_PATH_MAX_LENGTH: number = 200;

export function normalizeLocationPath(value?: string): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  const normalized = value.trim();
  return normalized.length === 0 ? undefined : normalized;
}
