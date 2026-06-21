import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { TraceEvent, TraceEventType } from '../../model/TraceEvent';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { TRACE_EVENT_TABLE } from '../rdb/TraceEventSchema';

export class TraceEventRepository {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async append(event: TraceEvent): Promise<Result<TraceEvent>> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const rowId = await store.insert(TRACE_EVENT_TABLE, this.toValues(event));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存操作记录失败，请重试');
        }
      });
      return success(event);
    } catch (error) {
      return failure<TraceEvent>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存操作记录失败，请重试'));
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
    const resultSet = await store.query(predicates);
    const events: TraceEvent[] = [];
    try {
      while (resultSet.goToNextRow()) {
        events.push(this.mapEvent(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return events;
  }

  private mapEvent(resultSet: relationalStore.ResultSet): TraceEvent {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      itemId: this.readString(resultSet, 'item_id') ?? '',
      batchId: this.readString(resultSet, 'batch_id'),
      type: (this.readString(resultSet, 'type') ?? TraceEventType.BORROW) as TraceEventType,
      quantity: this.readDouble(resultSet, 'quantity') ?? 0,
      counterpart: this.readString(resultSet, 'counterpart'),
      note: this.readString(resultSet, 'note'),
      createdAt: this.readLong(resultSet, 'created_at') ?? 0
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readDouble(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getDouble(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
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
      created_at: event.createdAt
    };
  }
}
