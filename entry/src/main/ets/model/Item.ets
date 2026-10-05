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
  NONE = 'NONE',
  LOCAL = 'LOCAL'
}

export interface Item {
  id: string;
  name: string;
  quantity: number;
  unit: ItemUnit;
  locationPath?: string;
  // 读取时计算的现存批次位置；空数组表示没有现存批次，locationPath仍保留默认存放位置。
  activeLocationPaths?: string[];
  category?: string;
  expirationDate?: string;
  reminderDays?: number;
  notes?: string;
  barcode?: string;
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
  category?: string;
  expirationDate?: string;
  reminderDays?: number;
  notes?: string;
  barcode?: string;
}

export interface ItemSummary {
  id: string;
  name: string;
  quantity: number;
  unit: ItemUnit;
  locationPath?: string;
  // 读取时计算的现存批次位置；空数组表示没有现存批次，locationPath仍保留默认存放位置。
  activeLocationPaths?: string[];
  category?: string;
  expirationDate?: string;
  expiryStatus: ExpiryStatus;
  stockStatus: StockStatus;
  photoLocalId?: string;
  photoPath?: string;
  createdAt: number;
  updatedAt: number;
}

export function isItemUnit(value: string): boolean {
  return ITEM_UNIT_OPTIONS.indexOf(value as ItemUnit) >= 0;
}
