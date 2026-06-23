import { NavigationRouteParams, RouteRefreshParams } from './RouteContract';

export function buildItemRefreshParams(refreshAt: number, itemId: string): NavigationRouteParams {
  return {
    refreshAt: normalizeRefreshAt(refreshAt),
    itemId: itemId
  };
}

export function buildBatchRefreshParams(refreshAt: number, itemId: string, batchId: string): NavigationRouteParams {
  return {
    refreshAt: normalizeRefreshAt(refreshAt),
    itemId: itemId,
    batchId: batchId
  };
}

export function getUnhandledRouteRefreshAt(params: RouteRefreshParams | undefined,
  lastHandledRefreshAt: number): number {
  const refreshAt = normalizeRefreshAt(params?.refreshAt ?? 0);
  if (refreshAt <= 0 || refreshAt === lastHandledRefreshAt) {
    return 0;
  }
  return refreshAt;
}

function normalizeRefreshAt(refreshAt: number): number {
  return refreshAt > 0 ? refreshAt : 0;
}
