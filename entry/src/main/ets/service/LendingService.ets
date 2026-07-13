import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { createTraceEventId, LendingState, TraceEvent, TraceEventType } from '../model/TraceEvent';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { TraceEventRepositoryPort } from '../data/repository/TraceEventRepository';

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
    return this.runExclusive(async (): Promise<Result<TraceEvent>> => {
      const validation = await this.validateOperation(itemId, quantity);
      if (!validation.ok) {
        return failure<TraceEvent>(validation.getError());
      }
      return this.events.append(this.createEvent(itemId, TraceEventType.BORROW, quantity, counterpart, batchId, note));
    });
  }

  async returnItem(itemId: string, quantity: number, batchId?: string, note?: string): Promise<Result<TraceEvent>> {
    return this.runExclusive(async (): Promise<Result<TraceEvent>> => {
      const validation = await this.validateOperation(itemId, quantity);
      if (!validation.ok) {
        return failure<TraceEvent>(validation.getError());
      }
      const stateResult = await this.getState(itemId, batchId);
      if (!stateResult.ok) {
        return failure<TraceEvent>(stateResult.getError());
      }
      if (quantity > stateResult.getData().borrowedQuantity) {
        return failure<TraceEvent>(new AppError(AppErrorCode.VALIDATION, '归还数量不能超过当前借出数量'));
      }
      return this.events.append(this.createEvent(itemId, TraceEventType.RETURN, quantity, undefined, batchId, note));
    });
  }

  async getEvents(itemId: string): Promise<Result<TraceEvent[]>> {
    return this.events.listByItemId(itemId);
  }

  async getState(itemId: string, batchId?: string): Promise<Result<LendingState>> {
    const eventsResult = await this.events.listByItemId(itemId);
    if (!eventsResult.ok) {
      return failure<LendingState>(eventsResult.getError());
    }
    let borrowed = 0;
    const events = eventsResult.getData();
    for (let index = 0; index < events.length; index++) {
      const event = events[index];
      if (batchId !== undefined && event.batchId !== batchId) {
        continue;
      }
      if (event.type === TraceEventType.BORROW) {
        borrowed += event.quantity;
      } else if (event.type === TraceEventType.RETURN) {
        borrowed -= event.quantity;
      }
    }
    const state: LendingState = {
      itemId: itemId,
      batchId: batchId,
      borrowedQuantity: borrowed
    };
    return success(state);
  }

  private async validateOperation(itemId: string, quantity: number): Promise<Result<void>> {
    const scaled = quantity * 100;
    if (!Number.isFinite(quantity) || quantity <= 0 || Math.abs(Math.round(scaled) - scaled) >= 1e-9) {
      return failure<void>(new AppError(AppErrorCode.VALIDATION, '数量必须是最多两位小数的正数'));
    }
    const itemResult = await this.items.getById(itemId);
    if (!itemResult.ok) {
      return failure<void>(itemResult.getError());
    }
    if (itemResult.getData() === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
    }
    return success<void>(undefined);
  }

  private async runExclusive(operation: () => Promise<Result<TraceEvent>>): Promise<Result<TraceEvent>> {
    const previous = this.operationQueue;
    let release: () => void = () => {};
    this.operationQueue = new Promise<void>((resolve: () => void) => {
      release = resolve;
    });
    await previous;
    try {
      return await operation();
    } finally {
      release();
    }
  }

  private createEvent(itemId: string, type: TraceEventType, quantity: number, counterpart?: string, batchId?: string, note?: string): TraceEvent {
    return {
      id: createTraceEventId(this.clock),
      itemId: itemId,
      batchId: batchId,
      type: type,
      quantity: quantity,
      counterpart: counterpart?.trim().length === 0 ? undefined : counterpart?.trim(),
      note: note?.trim().length === 0 ? undefined : note?.trim(),
      createdAt: this.clock()
    };
  }
}
