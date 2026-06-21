import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { ItemQuery } from '../model/ItemQuery';

export interface ItemRouteParams {
  itemId?: string;
}

export interface ItemFormRouteParams extends ItemRouteParams {
  mode?: 'create' | 'edit';
}

export interface BatchRouteParams extends ItemRouteParams {
  batchId?: string;
  mode?: 'create' | 'edit';
}

export interface ItemListRouteParams {
  query?: ItemQuery;
}

export function requireItemId(params: ItemRouteParams): Result<string> {
  const itemId = params.itemId?.trim() ?? '';
  if (itemId.length === 0) {
    return failure<string>(new AppError(AppErrorCode.ROUTE_INVALID, '缺少物品标识，无法打开页面'));
  }
  return success(itemId);
}

export function requireBatchId(params: BatchRouteParams): Result<string> {
  const batchId = params.batchId?.trim() ?? '';
  if (batchId.length === 0) {
    return failure<string>(new AppError(AppErrorCode.ROUTE_INVALID, '缺少批次标识，无法打开页面'));
  }
  return success(batchId);
}
