import { Category } from './Category';
import { ExpiryStatus } from './ExpiryStatus';
import { StockStatus } from './StockStatus';

export enum ItemUnit {
  PIECE = '个',
  BOX = '盒',
  BOTTLE = '瓶',
  PACK = '包',
  ITEM = '件',
  OTHER = '其他'
}

export const ITEM_UNIT_OPTIONS: ItemUnit[] = [
  ItemUnit.PIECE,
  ItemUnit.BOX,
  ItemUnit.BOTTLE,
  ItemUnit.PACK,
  ItemUnit.ITEM,
  ItemUnit.OTHER
];

export enum PhotoState {
  NONE = 'NONE'
}

export interface Item {
  id: string;
  name: string;
  quantity: number;
  unit: ItemUnit;
  locationPath?: string;
  category?: Category;
  expirationDate?: string;
  reminderDays?: number;
  notes?: string;
  photoState: PhotoState;
  photoLocalId?: string;
  createdAt: number;
  updatedAt: number;
}

export interface ItemDraft {
  name?: string;
  quantity?: number;
  unit?: ItemUnit;
  locationPath?: string;
  category?: Category;
  expirationDate?: string;
  reminderDays?: number;
  notes?: string;
}

export interface ItemSummary {
  id: string;
  name: string;
  quantity: number;
  unit: ItemUnit;
  locationPath?: string;
  category?: Category;
  expirationDate?: string;
  expiryStatus: ExpiryStatus;
  stockStatus: StockStatus;
  createdAt: number;
}

export function isItemUnit(value: string): boolean {
  return ITEM_UNIT_OPTIONS.indexOf(value as ItemUnit) >= 0;
}
