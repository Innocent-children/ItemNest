import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { ItemUnit } from '../../model/Item';
import { ReturnAllocation, TraceEvent, TraceEventType } from '../../model/TraceEvent';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { TRACE_EVENT_TABLE } from '../rdb/TraceEventSchema';
import { ResultSetReader } from '../rdb/ResultSetReader';

export interface LendingSnapshot {
  itemName: string;
  totalQuantity: number;
  unit: ItemUnit;
  events: TraceEvent[];
}

export interface TraceEventRepositoryPort {
  append(event: TraceEvent): Promise<Result<TraceEvent>>;
  update?(event: TraceEvent): Promise<Result<TraceEvent>>;
  mutateLending?(itemId: string, decide: (snapshot: LendingSnapshot) => Result<TraceEvent>): Promise<Result<TraceEvent>>;
  listByItemId(itemId: string): Promise<Result<TraceEvent[]>>;
  listAll(): Promise<Result<TraceEvent[]>>;
}

export class TraceEventRepository implements TraceEventRepositoryPort {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async append(event: TraceEvent): Promise<Result<TraceEvent>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        await this.insert(store, event);
      });
      return success(event);
    } catch (error) {
      return failure<TraceEvent>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存操作记录失败，请重试'));
    }
  }

  async update(event: TraceEvent): Promise<Result<TraceEvent>> {
    try {
      await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
        await this.updateInTransaction(store, event);
      });
      return success(event);
    } catch (error) {
      return failure<TraceEvent>(toAppError(error, AppErrorCode.DATABASE_WRITE, '纠正操作记录失败，请重试'));
    }
  }

  /** Inventory and records are checked in the same serialized transaction as the write. */
  async mutateLending(itemId: string, decide: (snapshot: LendingSnapshot) => Result<TraceEvent>): Promise<Result<TraceEvent>> {
    try {
      return await this.database.transaction(async (store: relationalStore.Transaction): Promise<Result<TraceEvent>> => {
        const itemRows = await store.querySql('SELECT name,quantity,unit FROM item WHERE id = ?', [itemId]);
        let itemName: string;
        let totalQuantity: number;
        let unit: ItemUnit;
        try {
          if (!ResultSetReader.goToFirstRow(itemRows)) {
            return failure<TraceEvent>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
          }
          itemName = ResultSetReader.readString(itemRows, 'name') ?? '';
          totalQuantity = ResultSetReader.readDouble(itemRows, 'quantity') ?? 0;
          unit = (ResultSetReader.readString(itemRows, 'unit') ?? ItemUnit.PIECE) as ItemUnit;
        } finally {
          ResultSetReader.close(itemRows);
        }
        const rows = await store.querySql('SELECT * FROM trace_event WHERE item_id = ? ORDER BY created_at DESC,id', [itemId]);
        const events = this.readEvents(rows);
        const result = decide({ itemName: itemName, totalQuantity: totalQuantity, unit: unit, events: events });
        if (!result.ok) {
          return result;
        }
        const event = result.getData();
        if (event.itemId !== itemId) {
          throw new AppError(AppErrorCode.VALIDATION, '操作记录与物品不一致');
        }
        if (events.some((existing: TraceEvent) => existing.id === event.id)) {
          await this.updateInTransaction(store, event);
        } else {
          await this.insert(store, event);
        }
        return success(event);
      });
    } catch (error) {
      return failure<TraceEvent>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存借还记录失败，请重试'));
    }
  }

  async listByItemId(itemId: string): Promise<Result<TraceEvent[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(TRACE_EVENT_TABLE);
      predicates.equalTo('item_id', itemId);
      predicates.orderByDesc('created_at');
      return success(await this.query(predicates));
    } catch (error) {
      return failure<TraceEvent[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取操作记录失败，请重试'));
    }
  }

  async listAll(): Promise<Result<TraceEvent[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(TRACE_EVENT_TABLE);
      predicates.orderByDesc('created_at');
      return success(await this.query(predicates));
    } catch (error) {
      return failure<TraceEvent[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取操作记录失败，请重试'));
    }
  }

  private async query(predicates: relationalStore.RdbPredicates): Promise<TraceEvent[]> {
    const store = await this.database.requireStore();
    return this.readEvents(await store.query(predicates));
  }

  private readEvents(resultSet: relationalStore.ResultSet): TraceEvent[] {
    const events: TraceEvent[] = [];
    try {
      while (ResultSetReader.goToNextRow(resultSet)) {
        const allocations = ResultSetReader.readString(resultSet, 'return_allocations_json');
        events.push({
          id: ResultSetReader.readString(resultSet, 'id') ?? '',
          itemId: ResultSetReader.readString(resultSet, 'item_id') ?? '',
          batchId: ResultSetReader.readString(resultSet, 'batch_id'),
          type: (ResultSetReader.readString(resultSet, 'type') ?? TraceEventType.BORROW) as TraceEventType,
          quantity: ResultSetReader.readDouble(resultSet, 'quantity') ?? 0,
          counterpart: ResultSetReader.readString(resultSet, 'counterpart'),
          note: ResultSetReader.readString(resultSet, 'note'),
          createdAt: ResultSetReader.readLong(resultSet, 'created_at') ?? 0,
          voidedAt: ResultSetReader.readLong(resultSet, 'voided_at'),
          returnAllocations: allocations === undefined ? undefined : JSON.parse(allocations) as ReturnAllocation[],
          legacyAllocated: (ResultSetReader.readLong(resultSet, 'legacy_allocated') ?? 0) === 1 ? true : undefined
        });
      }
    } finally {
      ResultSetReader.close(resultSet);
    }
    return events;
  }

  private async insert(store: relationalStore.Transaction, event: TraceEvent): Promise<void> {
    if (await store.insert(TRACE_EVENT_TABLE, this.toValues(event)) < 0) {
      throw new AppError(AppErrorCode.DATABASE_WRITE, '保存操作记录失败，请重试');
    }
  }

  private async updateInTransaction(store: relationalStore.Transaction, event: TraceEvent): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(TRACE_EVENT_TABLE);
    predicates.equalTo('id', event.id).equalTo('item_id', event.itemId);
    if (await store.update(this.toValues(event), predicates) !== 1) {
      throw new AppError(AppErrorCode.NOT_FOUND, '操作记录不存在，请重新加载');
    }
  }

  private toValues(event: TraceEvent): relationalStore.ValuesBucket {
    return {
      id: event.id,
      item_id: event.itemId,
      batch_id: event.batchId ?? null,
      type: event.type,
      quantity: event.quantity,
      counterpart: event.counterpart ?? null,
      note: event.note ?? null,
      created_at: event.createdAt,
      voided_at: event.voidedAt ?? null,
      return_allocations_json: event.returnAllocations === undefined ? null : JSON.stringify(event.returnAllocations),
      legacy_allocated: event.legacyAllocated === true ? 1 : 0
    };
  }
}
