import { CategoryRecord } from '../model/Category';
import { ItemUnit } from '../model/Item';

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

export function activeLocationText(locations: string[] | undefined, defaultLocation: string | undefined, quantity: number): string {
  if (locations === undefined) {
    return defaultLocation ?? '位置未设置';
  }
  if (locations.length === 0) {
    return quantity === 0 ? '无现存库存' : '现存批次位置未设置';
  }
  return locations.length === 1 ? locations[0] : `分存 ${locations.length} 处：${locations.join('；')}`;
}
