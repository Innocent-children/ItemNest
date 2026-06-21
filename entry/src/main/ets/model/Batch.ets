import { ItemUnit } from './Item';

export interface Batch {
  id: string;
  itemId: string;
  quantity: number;
  unit: ItemUnit;
  expirationDate?: string;
  locationPath?: string;
  notes?: string;
  createdAt: number;
  updatedAt: number;
}

export interface BatchDraft {
  itemId: string;
  quantity?: number;
  unit?: ItemUnit;
  expirationDate?: string;
  locationPath?: string;
  notes?: string;
}

export function createBatchId(clock: () => number = () => Date.now()): string {
  return `batch-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
