export class Batch {
  id: string = '';
  itemId: string = '';
  quantity: number = 0;
  unit: string = '个';
  expirationDate: string | null = null;
  locationPath: string | null = null;
  notes: string | null = null;
  createdAt: number = 0;
  updatedAt: number = 0;

  constructor(init?: Partial<Batch>) {
    Object.assign(this, init);
  }
}

export interface BatchDraft {
  itemId: string;
  quantity: number;
  unit?: string;
  expirationDate?: string | null;
  locationPath?: string | null;
  notes?: string | null;
}

export interface BatchSummary {
  id: string;
  itemId: string;
  itemName: string;
  quantity: number;
  unit: string;
  expirationDate: string | null;
  locationPath: string | null;
  dueSoon: boolean;
  expired: boolean;
}
