import { AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { ReminderRecord } from '../../model/ReminderRecord';
import { ReminderDao } from '../dao/ReminderDao';

export interface ReminderRepositoryPort {
  getByItemId(itemId: string): Promise<Result<ReminderRecord | undefined>>;
  save(record: ReminderRecord): Promise<Result<ReminderRecord>>;
  deleteByItemId(itemId: string): Promise<Result<void>>;
  countScheduledBetween(startAt: number, endAt: number): Promise<Result<number>>;
}

export class ReminderRepository implements ReminderRepositoryPort {
  private readonly dao: ReminderDao;

  constructor(dao: ReminderDao) {
    this.dao = dao;
  }

  async getByItemId(itemId: string): Promise<Result<ReminderRecord | undefined>> {
    try {
      return success<ReminderRecord | undefined>(await this.dao.findByItemId(itemId));
    } catch (error) {
      return failure<ReminderRecord | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取提醒记录失败，请重试'));
    }
  }

  async save(record: ReminderRecord): Promise<Result<ReminderRecord>> {
    try {
      await this.dao.save(record);
      return success<ReminderRecord>(record);
    } catch (error) {
      return failure<ReminderRecord>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存提醒记录失败，请重试'));
    }
  }

  async deleteByItemId(itemId: string): Promise<Result<void>> {
    try {
      await this.dao.deleteByItemId(itemId);
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '清理提醒记录失败，请重试'));
    }
  }

  async countScheduledBetween(startAt: number, endAt: number): Promise<Result<number>> {
    try {
      return success<number>(await this.dao.countScheduledBetween(startAt, endAt));
    } catch (error) {
      return failure<number>(toAppError(error, AppErrorCode.DATABASE_READ, '读取提醒记录失败，请重试'));
    }
  }
}
