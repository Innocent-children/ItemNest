import { CategoryRecord } from '../model/Category';
import { ItemUnit } from '../model/Item';
import { ExpiryStatus, expiryStatusLabel } from '../model/ExpiryStatus';

export function expiryDescription(status: ExpiryStatus, expirationDate: string, now: Date = new Date()): string {
  if (expirationDate.length === 0 || status === ExpiryStatus.NO_EXPIRY_DATE) { return expiryStatusLabel(status); }
  const parts = expirationDate.split('-');
  if (parts.length !== 3) { return expiryStatusLabel(status); }
  // 用日历日比较，跨夏令时的日期仍相差整天。
  const target = Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  const days = Math.round((target - today) / 86400000);
  if (!Number.isFinite(days)) { return expiryStatusLabel(status); }
  return days < 0 ? `已过期 ${-days} 天` : days === 0 ? '今天到期' : days === 1 ? '明天到期' : `${days} 天后到期`;
}

export function activeCategoryNames(categories: CategoryRecord[]): string[] {
  const names: string[] = [];
  for (const category of categories) {
    if (category.active && names.indexOf(category.name) < 0) {
      names.push(category.name);
    }
  }
  return names;
}

export function refreshedUnit(currentUnit: ItemUnit, loadedUnit: ItemUnit, latestUnit: ItemUnit): ItemUnit {
  return currentUnit === loadedUnit ? latestUnit : currentUnit;
}

export function activeLocationText(locations: string[] | undefined, defaultLocation: string | undefined,
  quantity: number, borrowedQuantity: number = 0): string {
  if (quantity > 0 && borrowedQuantity >= quantity) {
    const previous = locations === undefined ? defaultLocation : locations.join('；');
    return previous ? `已全部借出 · 原位置：${previous}` : '已全部借出，等待归还';
  }
  if (locations === undefined) {
    return defaultLocation ?? '位置未设置';
  }
  if (locations.length === 0) {
    return quantity === 0 ? '已经用完' : '还没填写存放位置';
  }
  return locations.length === 1 ? locations[0] : `分存 ${locations.length} 处：${locations.join('；')}`;
}
