import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { Batch } from '../model/Batch';

export interface ConsumptionAllocation {
  batch: Batch;
  quantity: number;
  remainingQuantity: number;
}

export function isValidStockQuantity(quantity: number): boolean {
  const scaled = quantity * 100;
  return Number.isFinite(quantity) && quantity >= 0 && Math.abs(Math.round(scaled) - scaled) < 1e-9;
}

export function validateInventoryReduction(currentQuantity: number, nextQuantity: number,
  borrowedQuantity: number): Result<void> {
  if (!isValidStockQuantity(nextQuantity)) {
    return failure<void>(new AppError(AppErrorCode.VALIDATION, '数量必须是最多两位小数的非负数'));
  }
  if (Math.round(nextQuantity * 100) < Math.round(currentQuantity * 100) &&
    Math.round(nextQuantity * 100) < Math.round(borrowedQuantity * 100)) {
    return failure<void>(new AppError(AppErrorCode.VALIDATION,
      `还有 ${borrowedQuantity} 未归还，总量不能减少到未归还数量以下；请先记录归还或纠正借出记录`));
  }
  return success<void>(undefined);
}

export function planConsumption(batches: Batch[], quantity: number, borrowedQuantity: number,
  batchId?: string): Result<ConsumptionAllocation[]> {
  if (!isValidStockQuantity(quantity) || quantity <= 0) {
    return failure<ConsumptionAllocation[]>(new AppError(AppErrorCode.VALIDATION, '请输入大于 0 且最多两位小数的消耗数量'));
  }
  const totalCents = batches.reduce((sum: number, batch: Batch) => sum + Math.round(batch.quantity * 100), 0);
  const availableCents = Math.max(0, totalCents - Math.round(borrowedQuantity * 100));
  const consumeCents = Math.round(quantity * 100);
  if (consumeCents > availableCents) {
    return failure<ConsumptionAllocation[]>(new AppError(AppErrorCode.VALIDATION,
      `在手只有 ${availableCents / 100}，不能消耗尚未归还的物品`));
  }
  const candidates = batches.filter((batch: Batch) => batch.quantity > 0 &&
    (batchId === undefined || batch.id === batchId));
  candidates.sort((left: Batch, right: Batch) => {
    const leftDate = left.expirationDate === undefined || left.expirationDate.length === 0 ? '9999-12-31' : left.expirationDate;
    const rightDate = right.expirationDate === undefined || right.expirationDate.length === 0 ? '9999-12-31' : right.expirationDate;
    if (leftDate !== rightDate) {
      return leftDate < rightDate ? -1 : 1;
    }
    return left.createdAt - right.createdAt;
  });
  let remaining = consumeCents;
  const allocations: ConsumptionAllocation[] = [];
  for (let index = 0; index < candidates.length && remaining > 0; index++) {
    const batch = candidates[index];
    const batchCents = Math.round(batch.quantity * 100);
    const consumed = Math.min(remaining, batchCents);
    allocations.push({ batch: batch, quantity: consumed / 100, remainingQuantity: (batchCents - consumed) / 100 });
    remaining -= consumed;
  }
  if (remaining > 0) {
    return failure<ConsumptionAllocation[]>(new AppError(AppErrorCode.VALIDATION, '所选批次的数量不足，请减少消耗数量或改为自动选择批次'));
  }
  return success(allocations);
}

export function isSameOrDescendantLocation(path: string, rootPath: string): boolean {
  const segments = path.split('/').map((segment: string) => segment.trim());
  const roots = rootPath.split('/').map((segment: string) => segment.trim());
  if (roots.length > segments.length) {
    return false;
  }
  for (let index = 0; index < roots.length; index++) {
    if (roots[index] !== segments[index]) {
      return false;
    }
  }
  return true;
}
