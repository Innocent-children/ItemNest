import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { ReminderRepositoryPort } from '../data/repository/ReminderRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { Item } from '../model/Item';
import { ReminderRecord, ReminderRecordStatus } from '../model/ReminderRecord';
import { PreferenceService } from './PreferenceService';
import { ReminderAdapter } from './adapter/ReminderAdapter';

const REMINDER_HOUR = 9;

export class ReminderService {
  private readonly repository: ReminderRepositoryPort;
  private readonly preferences: PreferenceService;
  private readonly adapter: ReminderAdapter;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;
  private readonly operationQueues: Map<string, Promise<void>> = new Map<string, Promise<void>>();

  constructor(repository: ReminderRepositoryPort, preferences: PreferenceService, adapter: ReminderAdapter, items: ItemRepositoryPort,
    clock: () => number = () => Date.now()) {
    this.repository = repository;
    this.preferences = preferences;
    this.adapter = adapter;
    this.items = items;
    this.clock = clock;
  }

  async reconcile(item: Item): Promise<Result<ReminderRecord>> {
    return this.runExclusive<ReminderRecord>(item.id, async (): Promise<Result<ReminderRecord>> => {
      return this.reconcileUnlocked(item);
    });
  }

  private async reconcileUnlocked(item: Item): Promise<Result<ReminderRecord>> {
    const currentRecordResult = await this.repository.getByItemId(item.id);
    if (!currentRecordResult.ok) {
      return failure<ReminderRecord>(currentRecordResult.getError());
    }
    const currentRecord = currentRecordResult.getData();
    const preferenceResult = await this.preferences.get();
    if (!preferenceResult.ok) {
      return failure<ReminderRecord>(preferenceResult.getError());
    }
    const userPreferences = preferenceResult.getData();
    const reminderAt = this.calculateReminderAt(item, userPreferences.defaultReminderDays);
    if (userPreferences.reminderEnabled && reminderAt !== undefined &&
      currentRecord?.status === ReminderRecordStatus.SCHEDULED &&
      currentRecord.systemReminderId !== undefined && currentRecord.scheduledAt === reminderAt) {
      return success(currentRecord);
    }

    const cancellationResult = await this.cancelExisting(item.id, currentRecord);
    if (!cancellationResult.ok) {
      return failure<ReminderRecord>(cancellationResult.getError());
    }
    if (!userPreferences.reminderEnabled || reminderAt === undefined) {
      const record = this.createRecord(item.id, undefined, undefined, ReminderRecordStatus.NOT_REQUIRED);
      return this.saveRecord(record);
    }

    const pendingRecord = this.createRecord(item.id, reminderAt, undefined, ReminderRecordStatus.FAILED, '提醒正在创建，请稍后重试');
    const pendingResult = await this.repository.save(pendingRecord);
    if (!pendingResult.ok) {
      return failure<ReminderRecord>(pendingResult.getError());
    }
    const scheduledResult = await this.adapter.schedule(item, reminderAt);
    if (!scheduledResult.ok) {
      const failedRecord = this.createRecord(item.id, reminderAt, undefined, ReminderRecordStatus.FAILED, scheduledResult.getError().message);
      const failedSaveResult = await this.repository.save(failedRecord);
      if (!failedSaveResult.ok) {
        return failure<ReminderRecord>(failedSaveResult.getError());
      }
      return failure<ReminderRecord>(scheduledResult.getError());
    }
    const scheduledRecord = this.createRecord(item.id, reminderAt, scheduledResult.getData(), ReminderRecordStatus.SCHEDULED);
    const savedResult = await this.repository.save(scheduledRecord);
    if (!savedResult.ok) {
      const compensationResult = await this.adapter.cancel(scheduledResult.getData());
      const recoverableRecord = this.createRecord(item.id, reminderAt,
        compensationResult.ok ? undefined : scheduledResult.getData(), ReminderRecordStatus.FAILED,
        compensationResult.ok ? '提醒记录保存失败，系统提醒已撤销' : '提醒记录保存失败，系统提醒仍需取消');
      await this.repository.save(recoverableRecord);
      return failure<ReminderRecord>(savedResult.getError());
    }
    return savedResult;
  }

  async cancelForItem(itemId: string): Promise<Result<void>> {
    return this.runExclusive<void>(itemId, async (): Promise<Result<void>> => {
      return this.cancelForItemUnlocked(itemId);
    });
  }

  private async cancelForItemUnlocked(itemId: string): Promise<Result<void>> {
    const currentRecordResult = await this.repository.getByItemId(itemId);
    if (!currentRecordResult.ok) {
      return failure<void>(currentRecordResult.getError());
    }
    const cancellationResult = await this.cancelExisting(itemId, currentRecordResult.getData());
    if (!cancellationResult.ok) {
      return cancellationResult;
    }
    return this.repository.deleteByItemId(itemId);
  }

  async getRecord(itemId: string): Promise<Result<ReminderRecord | undefined>> {
    return this.repository.getByItemId(itemId);
  }

  async cancelAllForDisabledPreference(): Promise<Result<void>> {
    const itemsResult = await this.items.listAll();
    if (!itemsResult.ok) {
      return failure<void>(itemsResult.getError());
    }
    const items = itemsResult.getData();
    let firstError: AppError | undefined = undefined;
    for (let index = 0; index < items.length; index++) {
      const cancelled = await this.cancelForItem(items[index].id);
      if (!cancelled.ok && firstError === undefined) {
        firstError = cancelled.getError();
      }
    }
    if (firstError !== undefined) {
      return failure<void>(firstError);
    }
    return success<void>(undefined);
  }

  private async cancelExisting(itemId: string, record?: ReminderRecord): Promise<Result<void>> {
    if (record?.systemReminderId === undefined) {
      return success<void>(undefined);
    }
    const pendingRecord = this.createRecord(itemId, record.scheduledAt, record.systemReminderId,
      ReminderRecordStatus.FAILED, '提醒正在更新，请稍后重试');
    const pendingResult = await this.repository.save(pendingRecord);
    if (!pendingResult.ok) {
      return failure<void>(pendingResult.getError());
    }
    const cancellationResult = await this.adapter.cancel(record.systemReminderId);
    if (!cancellationResult.ok) {
      const failedRecord = this.createRecord(itemId, record.scheduledAt, record.systemReminderId,
        ReminderRecordStatus.FAILED, cancellationResult.getError().message);
      await this.repository.save(failedRecord);
      return cancellationResult;
    }
    const cancelledRecord = this.createRecord(itemId, undefined, undefined, ReminderRecordStatus.CANCELLED);
    const savedResult = await this.repository.save(cancelledRecord);
    if (!savedResult.ok) {
      return failure<void>(savedResult.getError());
    }
    return success<void>(undefined);
  }

  private calculateReminderAt(item: Item, defaultReminderDays: number): number | undefined {
    if (item.expirationDate === undefined || item.expirationDate.length === 0) {
      return undefined;
    }
    const parts = item.expirationDate.split('-');
    if (parts.length !== 3) {
      return undefined;
    }
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    const reminderDate = new Date(year, month - 1, day, REMINDER_HOUR, 0, 0, 0);
    if (Number.isNaN(reminderDate.getTime()) || reminderDate.getFullYear() !== year ||
      reminderDate.getMonth() + 1 !== month || reminderDate.getDate() !== day) {
      return undefined;
    }
    const reminderDays = item.reminderDays ?? defaultReminderDays;
    reminderDate.setDate(reminderDate.getDate() - reminderDays);
    if (reminderDate.getTime() <= this.clock()) {
      return undefined;
    }
    return reminderDate.getTime();
  }

  private createRecord(itemId: string, scheduledAt: number | undefined, systemReminderId: number | undefined,
    status: ReminderRecordStatus, errorSummary?: string): ReminderRecord {
    return {
      itemId: itemId,
      scheduledAt: scheduledAt,
      systemReminderId: systemReminderId,
      status: status,
      errorSummary: errorSummary,
      updatedAt: this.clock()
    };
  }

  private async saveRecord(record: ReminderRecord): Promise<Result<ReminderRecord>> {
    const result = await this.repository.save(record);
    if (!result.ok) {
      return failure<ReminderRecord>(new AppError(AppErrorCode.DATABASE_WRITE, '保存提醒记录失败，请重试'));
    }
    return result;
  }

  private async runExclusive<T>(itemId: string, operation: () => Promise<Result<T>>): Promise<Result<T>> {
    const previous = this.operationQueues.get(itemId) ?? Promise.resolve();
    let release: () => void = () => {};
    const current = new Promise<void>((resolve: () => void) => {
      release = resolve;
    });
    this.operationQueues.set(itemId, current);
    await previous;
    try {
      return await operation();
    } finally {
      release();
      if (this.operationQueues.get(itemId) === current) {
        this.operationQueues.delete(itemId);
      }
    }
  }
}
