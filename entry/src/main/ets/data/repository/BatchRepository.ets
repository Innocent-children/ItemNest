import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { Batch } from '../../model/Batch';
import { BatchDao } from '../dao/BatchDao';

export interface BatchRepositoryPort {
  create(batch: Batch): Promise<Result<Batch>>;
  getById(batchId: string): Promise<Result<Batch | undefined>>;
  listByItemId(itemId: string): Promise<Result<Batch[]>>;
  listAll(): Promise<Result<Batch[]>>;
  update(batch: Batch): Promise<Result<Batch>>;
  deleteConfirmed(batchId: string): Promise<Result<void>>;
  consumeAtomic?(itemId: string, quantity: number, batchId: string | undefined, now: number): Promise<Result<void>>;
}

export class BatchRepository implements BatchRepositoryPort {
  private readonly dao: BatchDao;

  constructor(dao: BatchDao) {
    this.dao = dao;
  }

  async consumeAtomic(itemId: string, quantity: number, batchId: string | undefined, now: number): Promise<Result<void>> {
    try {
      await this.dao.consume(itemId, quantity, batchId, now);
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '记录消耗失败，请重试'));
    }
  }

  async create(batch: Batch): Promise<Result<Batch>> {
    try {
      await this.dao.create(batch);
      return success(batch);
    } catch (error) {
      return failure<Batch>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存批次失败，请重试'));
    }
  }

  async getById(batchId: string): Promise<Result<Batch | undefined>> {
    try {
      return success(await this.dao.findById(batchId));
    } catch (error) {
      return failure<Batch | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取批次失败，请重试'));
    }
  }

  async listByItemId(itemId: string): Promise<Result<Batch[]>> {
    try {
      return success(await this.dao.findByItemId(itemId));
    } catch (error) {
      return failure<Batch[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取批次失败，请重试'));
    }
  }

  async listAll(): Promise<Result<Batch[]>> {
    try {
      return success(await this.dao.findAll());
    } catch (error) {
      return failure<Batch[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取批次失败，请重试'));
    }
  }

  async update(batch: Batch): Promise<Result<Batch>> {
    try {
      const updated = await this.dao.update(batch);
      if (!updated) {
        return failure<Batch>(new AppError(AppErrorCode.NOT_FOUND, '批次不存在或已删除'));
      }
      return success(batch);
    } catch (error) {
      return failure<Batch>(toAppError(error, AppErrorCode.DATABASE_WRITE, '修改批次失败，请重试'));
    }
  }

  async deleteConfirmed(batchId: string): Promise<Result<void>> {
    try {
      const deleted = await this.dao.deleteById(batchId);
      if (!deleted) {
        return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '批次不存在或已删除'));
      }
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '删除批次失败，请重试'));
    }
  }
}
