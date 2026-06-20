export class TraceEvent {
  id: string = '';
  itemId: string = '';
  batchId: string | null = null;
  eventType: string = '';
  quantityBefore: number = 0;
  quantityAfter: number = 0;
  notes: string | null = null;
  timestamp: number = 0;
  constructor(init?: Partial<TraceEvent>) { Object.assign(this, init); }
}
