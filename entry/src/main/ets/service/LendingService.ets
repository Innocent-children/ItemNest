import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { allocateLegacyReturns, createTraceEventId, LendingState, OutstandingLoan, OutstandingItemLoan, ReturnAllocation, roundLendingQuantity, TraceEvent, TraceEventType } from '../model/TraceEvent';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { LendingSnapshot, TraceEventRepositoryPort } from '../data/repository/TraceEventRepository';

export class LendingService {
  private readonly events: TraceEventRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;
  private operationQueue: Promise<void> = Promise.resolve();

  constructor(events: TraceEventRepositoryPort, items: ItemRepositoryPort, clock: () => number = () => Date.now()) {
    this.events = events;
    this.items = items;
    this.clock = clock;
  }

  async borrow(itemId: string, quantity: number, counterpart?: string, batchId?: string, note?: string): Promise<Result<TraceEvent>> {
    return this.change(itemId, (snapshot: LendingSnapshot): Result<TraceEvent> => {
      const validation = this.validateQuantity(quantity);
      if (!validation.ok) {
        return failure<TraceEvent>(validation.getError());
      }
      const state = this.calculateState(itemId, snapshot);
      if (quantity > state.availableQuantity) {
        return this.invalid(`在手只有 ${state.availableQuantity}${state.unit}，借出数量不能超过在手数量`);
      }
      return success(this.createEvent(itemId, TraceEventType.BORROW, quantity, counterpart, batchId, note));
    });
  }

  async returnItem(itemId: string, quantity: number, batchId?: string, note?: string, borrowEventId?: string): Promise<Result<TraceEvent>> {
    return this.change(itemId, (snapshot: LendingSnapshot): Result<TraceEvent> => {
      const validation = this.validateQuantity(quantity);
      if (!validation.ok) {
        return failure<TraceEvent>(validation.getError());
      }
      const state = this.calculateState(itemId, snapshot, batchId);
      const loans = borrowEventId === undefined ? state.outstandingLoans :
        state.outstandingLoans.filter((loan: OutstandingLoan) => loan.borrowEvent.id === borrowEventId);
      if (loans.length === 0) {
        return this.invalid('这笔借出已全部归还或已撤销，请重新选择');
      }
      const allocations = this.allocateReturn(loans, quantity);
      if (!allocations.ok) {
        return failure<TraceEvent>(allocations.getError());
      }
      const counterpart = this.allocationCounterparts(snapshot.events, allocations.getData());
      const event = this.createEvent(itemId, TraceEventType.RETURN, quantity, counterpart, batchId, note);
      event.returnAllocations = allocations.getData();
      return success(event);
    });
  }

  async correctEvent(itemId: string, eventId: string, quantity: number, counterpart?: string, note?: string,
    borrowEventId?: string): Promise<Result<TraceEvent>> {
    return this.change(itemId, (snapshot: LendingSnapshot): Result<TraceEvent> => {
      const validation = this.validateQuantity(quantity);
      if (!validation.ok) {
        return failure<TraceEvent>(validation.getError());
      }
      allocateLegacyReturns(snapshot.events);
      const original = snapshot.events.find((event: TraceEvent) => event.id === eventId && event.voidedAt === undefined);
      if (original === undefined) {
        return this.invalid('记录已撤销或不存在，请重新加载');
      }
      if (original.type !== TraceEventType.BORROW && original.type !== TraceEventType.RETURN) {
        return this.invalid('这里只能纠正借出和归还记录');
      }
      const before = this.calculateState(itemId, snapshot);
      const changed = this.copyEvent(original);
      changed.quantity = quantity;
      changed.note = this.trimmed(note);
      if (original.type === TraceEventType.BORROW) {
        const alreadyReturned = this.returnedToLoan(snapshot.events, original.id);
        if (quantity < alreadyReturned) {
          return this.invalid(`这笔已归还 ${alreadyReturned}${snapshot.unit}，请先纠正或撤销对应归还记录`);
        }
        changed.counterpart = this.trimmed(counterpart);
      } else {
        const base: LendingSnapshot = {
          itemName: snapshot.itemName, totalQuantity: snapshot.totalQuantity, unit: snapshot.unit,
          events: snapshot.events.filter((event: TraceEvent) => event.id !== eventId)
        };
        const available = this.calculateState(itemId, base).outstandingLoans;
        const linkedIds = original.returnAllocations?.map((allocation: ReturnAllocation) => allocation.borrowEventId) ?? [];
        const loans = available.filter((loan: OutstandingLoan) => borrowEventId === undefined ?
          linkedIds.indexOf(loan.borrowEvent.id) >= 0 : loan.borrowEvent.id === borrowEventId);
        const allocations = this.allocateReturn(loans, quantity);
        if (!allocations.ok) {
          return failure<TraceEvent>(allocations.getError());
        }
        changed.returnAllocations = allocations.getData();
        changed.counterpart = this.allocationCounterparts(snapshot.events, allocations.getData());
        changed.legacyAllocated = false;
      }
      const proposed: LendingSnapshot = {
        itemName: snapshot.itemName, totalQuantity: snapshot.totalQuantity, unit: snapshot.unit,
        events: snapshot.events.map((event: TraceEvent) => event.id === eventId ? changed : event)
      };
      if (this.worsensInventory(before, this.calculateState(itemId, proposed))) {
        return this.invalid('纠正后未归还数量将超过总量，请先补正库存或纠正其他借还记录');
      }
      return success(changed);
    });
  }

  async voidEvent(itemId: string, eventId: string): Promise<Result<TraceEvent>> {
    return this.change(itemId, (snapshot: LendingSnapshot): Result<TraceEvent> => {
      allocateLegacyReturns(snapshot.events);
      const original = snapshot.events.find((event: TraceEvent) => event.id === eventId && event.voidedAt === undefined);
      if (original === undefined) {
        return this.invalid('记录已撤销或不存在，请重新加载');
      }
      if (original.type !== TraceEventType.BORROW && original.type !== TraceEventType.RETURN) {
        return this.invalid('这里只能撤销借出和归还记录');
      }
      if (original.type === TraceEventType.BORROW && this.returnedToLoan(snapshot.events, original.id) > 0) {
        return this.invalid('这笔借出已有归还记录，请先撤销对应归还记录');
      }
      const before = this.calculateState(itemId, snapshot);
      const changed = this.copyEvent(original);
      changed.voidedAt = this.clock();
      const proposed: LendingSnapshot = {
        itemName: snapshot.itemName, totalQuantity: snapshot.totalQuantity, unit: snapshot.unit,
        events: snapshot.events.map((event: TraceEvent) => event.id === eventId ? changed : event)
      };
      if (this.worsensInventory(before, this.calculateState(itemId, proposed))) {
        return this.invalid('撤销这次归还后，未归还数量会超过总量，请先补正库存');
      }
      return success(changed);
    });
  }

  async getEvents(itemId: string): Promise<Result<TraceEvent[]>> {
    const result = await this.events.listByItemId(itemId);
    return result.ok ? success(allocateLegacyReturns(result.getData())) : result;
  }

  async getOutstandingLoans(): Promise<Result<OutstandingItemLoan[]>> {
    const items = await this.items.listAll();
    if (!items.ok) { return failure<OutstandingItemLoan[]>(items.getError()); }
    const events = await this.events.listAll();
    if (!events.ok) { return failure<OutstandingItemLoan[]>(events.getError()); }
    const grouped = new Map<string, TraceEvent[]>();
    for (const event of events.getData()) {
      const list = grouped.get(event.itemId) ?? [];
      list.push(event);
      grouped.set(event.itemId, list);
    }
    const result: OutstandingItemLoan[] = [];
    for (const item of items.getData()) {
      const itemEvents = grouped.get(item.id);
      if (itemEvents === undefined) { continue; }
      const state = this.calculateState(item.id, {
        itemName: item.name, totalQuantity: item.quantity, unit: item.unit, events: itemEvents
      });
      for (const loan of state.outstandingLoans) {
        result.push({ itemId: item.id, itemName: item.name, unit: item.unit, loan: loan });
      }
    }
    result.sort((left: OutstandingItemLoan, right: OutstandingItemLoan) => left.loan.borrowEvent.createdAt - right.loan.borrowEvent.createdAt);
    return success(result);
  }

  async getState(itemId: string, batchId?: string): Promise<Result<LendingState>> {
    const item = await this.items.getById(itemId);
    if (!item.ok) {
      return failure<LendingState>(item.getError());
    }
    const found = item.getData();
    if (found === undefined) {
      return failure<LendingState>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    const result = await this.events.listByItemId(itemId);
    if (!result.ok) {
      return failure<LendingState>(result.getError());
    }
    return success(this.calculateState(itemId, {
      itemName: found.name, totalQuantity: found.quantity, unit: found.unit, events: result.getData()
    }, batchId));
  }

  private calculateState(itemId: string, snapshot: LendingSnapshot, batchId?: string): LendingState {
    const events = allocateLegacyReturns(snapshot.events);
    const loans: OutstandingLoan[] = [];
    let unallocated = 0;
    for (let index = 0; index < events.length; index++) {
      const event = events[index];
      if (event.type === TraceEventType.BORROW && event.voidedAt === undefined &&
        (batchId === undefined || event.batchId === batchId)) {
        const returned = this.returnedToLoan(events, event.id);
        loans.push({ borrowEvent: event, remainingQuantity: roundLendingQuantity(Math.max(0, event.quantity - returned)) });
      }
      if (event.type === TraceEventType.RETURN && event.voidedAt === undefined &&
        (batchId === undefined || event.batchId === batchId)) {
        let matched = 0;
        const allocations = event.returnAllocations ?? [];
        for (let allocationIndex = 0; allocationIndex < allocations.length; allocationIndex++) {
          const allocation = allocations[allocationIndex];
          if (events.some((borrow: TraceEvent) => borrow.id === allocation.borrowEventId &&
            borrow.type === TraceEventType.BORROW && borrow.voidedAt === undefined)) {
            matched += allocation.quantity;
          }
        }
        unallocated += Math.max(0, event.quantity - matched);
      }
    }
    const outstanding = loans.filter((loan: OutstandingLoan) => loan.remainingQuantity > 0).sort(
      (left: OutstandingLoan, right: OutstandingLoan) => left.borrowEvent.createdAt - right.borrowEvent.createdAt);
    let borrowed = 0;
    for (let index = 0; index < outstanding.length; index++) {
      borrowed += outstanding[index].remainingQuantity;
    }
    borrowed = roundLendingQuantity(borrowed);
    const warnings: string[] = [];
    if (borrowed > snapshot.totalQuantity) {
      warnings.push(`旧记录中未归还 ${borrowed}${snapshot.unit}，超过总量 ${snapshot.totalQuantity}${snapshot.unit}。请补正库存或纠正借还记录。`);
    }
    if (unallocated > 0) {
      warnings.push(`旧归还记录有 ${roundLendingQuantity(unallocated)}${snapshot.unit} 未对应借出，已保留原记录，请核对并纠正。`);
    }
    return {
      itemId: itemId, batchId: batchId, itemName: snapshot.itemName, unit: snapshot.unit,
      totalQuantity: snapshot.totalQuantity, borrowedQuantity: borrowed,
      availableQuantity: roundLendingQuantity(Math.max(0, snapshot.totalQuantity - borrowed)),
      outstandingLoans: outstanding, unallocatedReturnQuantity: roundLendingQuantity(unallocated),
      inventoryWarning: warnings.length > 0 ? warnings.join(' ') : undefined
    };
  }

  private allocationCounterparts(events: TraceEvent[], allocations: ReturnAllocation[]): string {
    return allocations.map((allocation: ReturnAllocation) => {
      const borrow = events.find((event: TraceEvent) => event.id === allocation.borrowEventId);
      return borrow?.counterpart ?? '未填写借用人';
    }).join('、');
  }

  private returnedToLoan(events: TraceEvent[], borrowId: string): number {
    let returned = 0;
    for (let index = 0; index < events.length; index++) {
      const event = events[index];
      if (event.type !== TraceEventType.RETURN || event.voidedAt !== undefined) {
        continue;
      }
      const allocations = event.returnAllocations ?? [];
      for (let allocationIndex = 0; allocationIndex < allocations.length; allocationIndex++) {
        if (allocations[allocationIndex].borrowEventId === borrowId) {
          returned += allocations[allocationIndex].quantity;
        }
      }
    }
    return roundLendingQuantity(returned);
  }

  private allocateReturn(loans: OutstandingLoan[], quantity: number): Result<ReturnAllocation[]> {
    let remaining = quantity;
    const allocations: ReturnAllocation[] = [];
    for (let index = 0; index < loans.length && remaining > 0; index++) {
      const allocated = roundLendingQuantity(Math.min(remaining, loans[index].remainingQuantity));
      if (allocated > 0) {
        allocations.push({ borrowEventId: loans[index].borrowEvent.id, quantity: allocated });
        remaining = roundLendingQuantity(remaining - allocated);
      }
    }
    return remaining > 0 ? failure<ReturnAllocation[]>(new AppError(AppErrorCode.VALIDATION,
      '归还数量不能超过所选借出记录的未归还数量')) : success(allocations);
  }

  private worsensInventory(before: LendingState, after: LendingState): boolean {
    return after.borrowedQuantity > after.totalQuantity && after.borrowedQuantity > before.borrowedQuantity;
  }

  private validateQuantity(quantity: number): Result<void> {
    const scaled = quantity * 100;
    if (!Number.isFinite(quantity) || quantity <= 0 || Math.abs(Math.round(scaled) - scaled) >= 1e-9) {
      return failure<void>(new AppError(AppErrorCode.VALIDATION, '数量必须是最多两位小数的正数'));
    }
    return success<void>(undefined);
  }

  private invalid(message: string): Result<TraceEvent> {
    return failure<TraceEvent>(new AppError(AppErrorCode.VALIDATION, message));
  }

  private async change(itemId: string, decide: (snapshot: LendingSnapshot) => Result<TraceEvent>): Promise<Result<TraceEvent>> {
    return this.runExclusive(async (): Promise<Result<TraceEvent>> => {
      if (this.events.mutateLending !== undefined) {
        return this.events.mutateLending(itemId, decide);
      }
      // Lightweight repositories used by local tests keep the same checks; the database port uses one transaction.
      const itemResult = await this.items.getById(itemId);
      if (!itemResult.ok) {
        return failure<TraceEvent>(itemResult.getError());
      }
      const item = itemResult.getData();
      if (item === undefined) {
        return failure<TraceEvent>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
      }
      const events = await this.events.listByItemId(itemId);
      if (!events.ok) {
        return failure<TraceEvent>(events.getError());
      }
      const result = decide({ itemName: item.name, totalQuantity: item.quantity, unit: item.unit, events: events.getData() });
      if (!result.ok) {
        return result;
      }
      if (events.getData().some((event: TraceEvent) => event.id === result.getData().id)) {
        return this.events.update === undefined ? this.invalid('当前存储暂不支持纠正记录') : this.events.update(result.getData());
      }
      return this.events.append(result.getData());
    });
  }

  private async runExclusive(operation: () => Promise<Result<TraceEvent>>): Promise<Result<TraceEvent>> {
    const previous = this.operationQueue;
    let release: () => void = () => {};
    this.operationQueue = new Promise<void>((resolve: () => void) => { release = resolve; });
    await previous;
    try {
      return await operation();
    } finally {
      release();
    }
  }

  private trimmed(value?: string): string | undefined {
    return value === undefined || value.trim().length === 0 ? undefined : value.trim();
  }

  private copyEvent(event: TraceEvent): TraceEvent {
    return {
      id: event.id, itemId: event.itemId, batchId: event.batchId, type: event.type, quantity: event.quantity,
      counterpart: event.counterpart, note: event.note, createdAt: event.createdAt, voidedAt: event.voidedAt,
      returnAllocations: event.returnAllocations?.slice(), legacyAllocated: event.legacyAllocated
    };
  }

  private createEvent(itemId: string, type: TraceEventType, quantity: number, counterpart?: string, batchId?: string, note?: string): TraceEvent {
    return {
      id: createTraceEventId(this.clock), itemId: itemId, batchId: batchId, type: type, quantity: quantity,
      counterpart: this.trimmed(counterpart), note: this.trimmed(note), createdAt: this.clock()
    };
  }
}
