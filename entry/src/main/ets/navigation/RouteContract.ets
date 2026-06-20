import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { ItemQuery } from '../model/ItemQuery';

export interface ItemRouteParams {
  itemId?: string;
}

export interface ItemFormRouteParams extends ItemRouteParams {
  mode?: 'create' | 'edit';
}

export interface ItemOperationResult {
  operation: 'created' | 'updated' | 'deleted';
  itemId: string;
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

export function createItemResult(operation: 'created' | 'updated' | 'deleted', itemId: string): ItemOperationResult {
  return { operation: operation, itemId: itemId };
}
