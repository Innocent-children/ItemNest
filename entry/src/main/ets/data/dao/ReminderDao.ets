import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { ReminderRecord, ReminderRecordStatus } from '../../model/ReminderRecord';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { REMINDER_TABLE } from '../rdb/ReminderSchema';

export class ReminderDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async findByItemId(itemId: string): Promise<ReminderRecord | undefined> {
    try {
      const predicates = new relationalStore.RdbPredicates(REMINDER_TABLE);
      predicates.equalTo('item_id', itemId);
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      try {
        if (!resultSet.goToFirstRow()) {
          return undefined;
        }
        return this.mapRecord(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取提醒记录失败，请重试');
    }
  }

  async save(record: ReminderRecord): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(REMINDER_TABLE);
        predicates.equalTo('item_id', record.itemId);
        const changed = await store.update(this.toValues(record), predicates);
        if (changed === 0) {
          const rowId = await store.insert(REMINDER_TABLE, this.toValues(record));
          if (rowId < 0) {
            throw new AppError(AppErrorCode.DATABASE_WRITE, '保存提醒记录失败，请重试');
          }
        }
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '保存提醒记录失败，请重试');
    }
  }

  async countScheduledBetween(startAt: number, endAt: number): Promise<number> {
    try {
      const predicates = new relationalStore.RdbPredicates(REMINDER_TABLE);
      predicates.equalTo('status', ReminderRecordStatus.SCHEDULED);
      predicates.greaterThanOrEqualTo('scheduled_at', startAt);
      predicates.lessThan('scheduled_at', endAt);
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      let count = 0;
      try {
        while (resultSet.goToNextRow()) {
          count++;
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取提醒记录失败，请重试');
    }
  }

  async deleteByItemId(itemId: string): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(REMINDER_TABLE);
        predicates.equalTo('item_id', itemId);
        await store.delete(predicates);
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '清理提醒记录失败，请重试');
    }
  }

  private mapRecord(resultSet: relationalStore.ResultSet): ReminderRecord {
    return {
      itemId: this.readString(resultSet, 'item_id') ?? '',
      scheduledAt: this.readLong(resultSet, 'scheduled_at'),
      systemReminderId: this.readLong(resultSet, 'system_reminder_id'),
      status: (this.readString(resultSet, 'status') ?? ReminderRecordStatus.FAILED) as ReminderRecordStatus,
      errorSummary: this.readString(resultSet, 'error_summary'),
      updatedAt: this.readLong(resultSet, 'updated_at') ?? 0
    };
  }

  private toValues(record: ReminderRecord): relationalStore.ValuesBucket {
    return {
      item_id: record.itemId,
      scheduled_at: record.scheduledAt ?? null,
      system_reminder_id: record.systemReminderId ?? null,
      status: record.status,
      error_summary: record.errorSummary ?? null,
      updated_at: record.updatedAt
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
  }
}
