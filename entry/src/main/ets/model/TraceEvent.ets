export enum TraceEventType {
  BORROW = 'BORROW',
  RETURN = 'RETURN',
  QUANTITY_ADJUST = 'QUANTITY_ADJUST',
  IMPORT = 'IMPORT',
  EXPORT = 'EXPORT'
}

export interface TraceEvent {
  id: string;
  itemId: string;
  batchId?: string;
  type: TraceEventType;
  quantity: number;
  counterpart?: string;
  note?: string;
  createdAt: number;
}

export interface LendingState {
  itemId: string;
  batchId?: string;
  borrowedQuantity: number;
}

export function createTraceEventId(clock: () => number = () => Date.now()): string {
  return `trace-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
