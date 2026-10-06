import { ItemUnit } from './Item';

export enum TraceEventType {
  BORROW = 'BORROW',
  RETURN = 'RETURN',
  CONSUME = 'CONSUME',
  QUANTITY_ADJUST = 'QUANTITY_ADJUST',
  IMPORT = 'IMPORT',
  EXPORT = 'EXPORT'
}

export interface ReturnAllocation {
  borrowEventId: string;
  quantity: number;
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
  voidedAt?: number;
  returnAllocations?: ReturnAllocation[];
  legacyAllocated?: boolean;
}

export interface OutstandingLoan {
  borrowEvent: TraceEvent;
  remainingQuantity: number;
}

export interface OutstandingItemLoan {
  itemId: string;
  itemName: string;
  unit: ItemUnit;
  loan: OutstandingLoan;
}

export interface LendingState {
  itemId: string;
  batchId?: string;
  itemName: string;
  unit: ItemUnit;
  totalQuantity: number;
  borrowedQuantity: number;
  availableQuantity: number;
  outstandingLoans: OutstandingLoan[];
  unallocatedReturnQuantity: number;
  inventoryWarning?: string;
}

export function roundLendingQuantity(quantity: number): number {
  return Math.round(quantity * 100) / 100;
}

/** Old records remain intact. Only missing return relationships are filled in, oldest loan first. */
export function allocateLegacyReturns(events: TraceEvent[]): TraceEvent[] {
  const ordered = events.slice().sort((left: TraceEvent, right: TraceEvent) => {
    return left.createdAt === right.createdAt ? left.id.localeCompare(right.id) : left.createdAt - right.createdAt;
  });
  const loans: OutstandingLoan[] = [];
  // Explicit relationships remain valid even if the device clock changed between operations.
  for (let index = 0; index < ordered.length; index++) {
    const event = ordered[index];
    if (event.voidedAt !== undefined) {
      continue;
    }
    if (event.type === TraceEventType.BORROW) {
      let reserved = 0;
      for (let returnIndex = 0; returnIndex < ordered.length; returnIndex++) {
        const returned = ordered[returnIndex];
        if (returned.type !== TraceEventType.RETURN || returned.voidedAt !== undefined) {
          continue;
        }
        const known = returned.returnAllocations ?? [];
        for (let knownIndex = 0; knownIndex < known.length; knownIndex++) {
          if (known[knownIndex].borrowEventId === event.id) {
            reserved += known[knownIndex].quantity;
          }
        }
      }
      loans.push({ borrowEvent: event, remainingQuantity: roundLendingQuantity(Math.max(0, event.quantity - reserved)) });
      continue;
    }
    if (event.type !== TraceEventType.RETURN || event.returnAllocations !== undefined) {
      continue;
    }
    const allocations: ReturnAllocation[] = [];
    let remaining = event.quantity;
    for (let loanIndex = 0; loanIndex < loans.length && remaining > 0; loanIndex++) {
      const loan = loans[loanIndex];
      if (loan.borrowEvent.itemId !== event.itemId ||
        (event.batchId !== undefined && loan.borrowEvent.batchId !== event.batchId)) {
        continue;
      }
      const quantity = roundLendingQuantity(Math.min(remaining, loan.remainingQuantity));
      if (quantity > 0) {
        allocations.push({ borrowEventId: loan.borrowEvent.id, quantity: quantity });
        loan.remainingQuantity = roundLendingQuantity(loan.remainingQuantity - quantity);
        remaining = roundLendingQuantity(remaining - quantity);
      }
    }
    event.returnAllocations = allocations;
    event.legacyAllocated = true;
  }
  return events;
}

export function createTraceEventId(clock: () => number = () => Date.now()): string {
  return `trace-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
