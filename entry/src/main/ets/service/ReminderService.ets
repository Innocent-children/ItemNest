import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { ReminderRepositoryPort } from '../data/repository/ReminderRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { Item } from '../model/Item';
import { ReminderRecord, ReminderRecordStatus } from '../model/ReminderRecord';
import { PreferenceService } from './PreferenceService';
import { ReminderAdapter } from './adapter/ReminderAdapter';

const REMINDER_HOUR = 9;
const MINUTE_MS = 60 * 1000;

interface ReminderPlan {
  scheduledAt?: number;
  originalAt?: number;
  key?: string;
  reason?: string;
}

export interface ReminderReconcileSummary {
  total: number;
  scheduled: number;
  due: number;
  notRequired: number;
  failed: number;
  failures: string[];
}

export class ReminderService {
  private readonly repository: ReminderRepositoryPort;
  private readonly preferences: PreferenceService;
  private readonly adapter: ReminderAdapter;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;
  private readonly operationQueues: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private batchQueue: Promise<void> = Promise.resolve();

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

  // Read after acquiring the item queue: a delayed page cannot replace a newer batch plan.
  async reconcileLatest(itemId: string): Promise<Result<ReminderRecord>> {
    return this.runExclusive<ReminderRecord>(itemId, async (): Promise<Result<ReminderRecord>> => {
      const latest = await this.items.getById(itemId);
      if (!latest.ok) {
        return failure<ReminderRecord>(latest.getError());
      }
      const item = latest.getData();
      if (item === undefined) {
        return failure<ReminderRecord>(new AppError(AppErrorCode.NOT_FOUND, '物品不存在或已删除'));
      }
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
    const plan: ReminderPlan = userPreferences.reminderEnabled ? this.calculatePlan(item, userPreferences.defaultReminderDays) :
      { reason: '系统提醒未启用，可在设置中开启并同步已有物品。' };
    const signature = `${item.name}\n${item.expirationDate ?? ''}`;
    const samePlan = plan.key !== undefined && (currentRecord?.planKey === plan.key ||
      (currentRecord?.planKey === undefined && currentRecord?.scheduledAt === plan.originalAt));

    // A one-time reminder is never sent repeatedly just because its planned time has passed.
    if (samePlan && currentRecord?.scheduledAt !== undefined && currentRecord.scheduledAt <= this.clock() &&
      (currentRecord.status === ReminderRecordStatus.SCHEDULED || currentRecord.status === ReminderRecordStatus.DUE)) {
      return this.saveRecord(this.createRecord(item.id, currentRecord.scheduledAt, currentRecord.systemReminderId,
        ReminderRecordStatus.DUE, '已到提醒时间；实际通知是否送达由系统决定，请检查通知或物品。',
        plan.key, signature));
    }
    if (plan.scheduledAt !== undefined && this.adapter.checkPermission !== undefined) {
      const permission = await this.adapter.checkPermission();
      if (!permission.ok) {
        const denied = this.createRecord(item.id, currentRecord?.scheduledAt ?? plan.scheduledAt,
          currentRecord?.systemReminderId, ReminderRecordStatus.FAILED, permission.getError().message,
          currentRecord?.planKey ?? plan.key, currentRecord?.contentSignature ?? signature);
        const saved = await this.saveRecord(denied);
        return saved.ok ? failure<ReminderRecord>(permission.getError()) : saved;
      }
    }
    if (samePlan && currentRecord?.status === ReminderRecordStatus.SCHEDULED &&
      currentRecord.systemReminderId !== undefined && currentRecord.scheduledAt !== undefined &&
      currentRecord.scheduledAt > this.clock() && currentRecord.contentSignature === signature) {
      return success(currentRecord);
    }

    const cancellationResult = await this.cancelExisting(item.id, currentRecord);
    if (!cancellationResult.ok) {
      return failure<ReminderRecord>(cancellationResult.getError());
    }
    if (plan.scheduledAt === undefined) {
      return this.saveRecord(this.createRecord(item.id, undefined, undefined, ReminderRecordStatus.NOT_REQUIRED,
        plan.reason, plan.key, signature));
    }
    // A name edit must update the notification, without postponing an existing near-time plan.
    const reminderAt = samePlan && currentRecord?.scheduledAt !== undefined && currentRecord.scheduledAt > this.clock()
      ? currentRecord.scheduledAt : plan.scheduledAt;
    const pendingRecord = this.createRecord(item.id, reminderAt, undefined, ReminderRecordStatus.FAILED,
      '提醒正在创建，请稍后重试', plan.key, signature);
    const pendingResult = await this.repository.save(pendingRecord);
    if (!pendingResult.ok) {
      return failure<ReminderRecord>(pendingResult.getError());
    }
    const scheduledResult = await this.adapter.schedule(item, reminderAt);
    if (!scheduledResult.ok) {
      const failedRecord = this.createRecord(item.id, reminderAt, undefined, ReminderRecordStatus.FAILED,
        scheduledResult.getError().message, plan.key, signature);
      const failedSaveResult = await this.repository.save(failedRecord);
      if (!failedSaveResult.ok) {
        return failure<ReminderRecord>(failedSaveResult.getError());
      }
      return failure<ReminderRecord>(scheduledResult.getError());
    }
    const scheduleNotice = plan.originalAt !== undefined && reminderAt > plan.originalAt
      ? '原计划提醒时间已过，已改为最近可用时间。' : undefined;
    const scheduledRecord = this.createRecord(item.id, reminderAt, scheduledResult.getData(), ReminderRecordStatus.SCHEDULED,
      scheduleNotice, plan.key, signature);
    const savedResult = await this.repository.save(scheduledRecord);
    if (!savedResult.ok) {
      const compensationResult = await this.adapter.cancel(scheduledResult.getData());
      const recoverableRecord = this.createRecord(item.id, reminderAt,
        compensationResult.ok ? undefined : scheduledResult.getData(), ReminderRecordStatus.FAILED,
        compensationResult.ok ? '提醒记录保存失败，系统提醒已撤销' : '提醒记录保存失败，系统提醒仍需取消', plan.key, signature);
      await this.repository.save(recoverableRecord);
      return failure<ReminderRecord>(savedResult.getError());
    }
    return savedResult;
  }

  // One full pass at a time. Each item reads the latest saved settings and latest stock.
  async reconcileAll(): Promise<Result<ReminderReconcileSummary>> {
    const previous = this.batchQueue;
    let release: () => void = () => {};
    this.batchQueue = new Promise<void>((resolve: () => void) => { release = resolve; });
    await previous;
    try {
      const itemsResult = await this.items.listAll();
      if (!itemsResult.ok) {
        return failure<ReminderReconcileSummary>(itemsResult.getError());
      }
      const allItems = itemsResult.getData();
      const summary: ReminderReconcileSummary = {
        total: allItems.length, scheduled: 0, due: 0, notRequired: 0, failed: 0, failures: []
      };
      for (let index = 0; index < allItems.length; index++) {
        const item = allItems[index];
        const result = await this.reconcileLatest(item.id);
        if (!result.ok) {
          summary.failed++;
          summary.failures.push(`${item.name}：${result.getError().message}`);
        } else if (result.getData().status === ReminderRecordStatus.SCHEDULED) {
          summary.scheduled++;
        } else if (result.getData().status === ReminderRecordStatus.DUE) {
          summary.due++;
        } else {
          summary.notRequired++;
        }
      }
      return success(summary);
    } finally {
      release();
    }
  }

  describeSummary(summary: ReminderReconcileSummary): string {
    const text = `已检查 ${summary.total} 个物品：${summary.scheduled} 个已安排、${summary.due} 个已到提醒时间、` +
      `${summary.notRequired} 个无需提醒、${summary.failed} 个失败。`;
    return summary.failed === 0 ? text : `${text}\n${summary.failures.join('\n')}\n可重新同步提醒；不会重复创建已安排的提醒。`;
  }

  describeRecord(record?: ReminderRecord): string {
    if (record === undefined) {
      return '尚未同步系统提醒，点击“同步提醒”检查当前设置和到期日。';
    }
    if (record.status === ReminderRecordStatus.SCHEDULED && record.scheduledAt !== undefined) {
      return record.scheduledAt > this.clock()
        ? `已安排系统提醒：${this.formatTime(record.scheduledAt)}${record.errorSummary === undefined ? '' : `。${record.errorSummary}`}` :
        `已到提醒时间：${this.formatTime(record.scheduledAt)}；实际通知是否送达由系统决定。`;
    }
    if (record.status === ReminderRecordStatus.DUE) {
      return `已到提醒时间${record.scheduledAt !== undefined ? `：${this.formatTime(record.scheduledAt)}` : ''}；` +
        '实际通知是否送达由系统决定，请检查通知或物品。';
    }
    if (record.status === ReminderRecordStatus.FAILED) {
      return `提醒未同步：${record.errorSummary ?? '请稍后重试'}`;
    }
    return record.errorSummary ?? (record.status === ReminderRecordStatus.CANCELLED ? '系统提醒已取消。' : '当前物品无需系统提醒。');
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
    return this.runExclusive<ReminderRecord | undefined>(itemId, async (): Promise<Result<ReminderRecord | undefined>> => {
      const result = await this.repository.getByItemId(itemId);
      if (!result.ok) {
        return result;
      }
      const record = result.getData();
      if (record?.status === ReminderRecordStatus.SCHEDULED && record.scheduledAt !== undefined && record.scheduledAt <= this.clock()) {
        const updated = this.createRecord(record.itemId, record.scheduledAt, record.systemReminderId,
          ReminderRecordStatus.DUE, '已到提醒时间；实际通知是否送达由系统决定。', record.planKey, record.contentSignature);
        return this.saveRecord(updated);
      }
      return result;
    });
  }

  async cancelAllForDisabledPreference(): Promise<Result<void>> {
    const itemsResult = await this.items.listAll();
    if (!itemsResult.ok) {
      return failure<void>(itemsResult.getError());
    }
    const allItems = itemsResult.getData();
    let firstError: AppError | undefined = undefined;
    for (let index = 0; index < allItems.length; index++) {
      const cancelled = await this.cancelForItem(allItems[index].id);
      if (!cancelled.ok && firstError === undefined) {
        firstError = cancelled.getError();
      }
    }
    return firstError !== undefined ? failure<void>(firstError) : success<void>(undefined);
  }

  private async cancelExisting(itemId: string, record?: ReminderRecord): Promise<Result<void>> {
    if (record?.systemReminderId === undefined) {
      return success<void>(undefined);
    }
    const pendingRecord = this.createRecord(itemId, record.scheduledAt, record.systemReminderId,
      ReminderRecordStatus.FAILED, '提醒正在更新，请稍后重试', record.planKey, record.contentSignature);
    const pendingResult = await this.repository.save(pendingRecord);
    if (!pendingResult.ok) {
      return failure<void>(pendingResult.getError());
    }
    const cancellationResult = await this.adapter.cancel(record.systemReminderId);
    if (!cancellationResult.ok) {
      const failedRecord = this.createRecord(itemId, record.scheduledAt, record.systemReminderId,
        ReminderRecordStatus.FAILED, cancellationResult.getError().message, record.planKey, record.contentSignature);
      await this.repository.save(failedRecord);
      return cancellationResult;
    }
    const savedResult = await this.repository.save(this.createRecord(itemId, undefined, undefined, ReminderRecordStatus.CANCELLED));
    return savedResult.ok ? success<void>(undefined) : failure<void>(savedResult.getError());
  }

  private calculatePlan(item: Item, defaultReminderDays: number): ReminderPlan {
    if (item.quantity <= 0) {
      return { reason: '当前库存为 0，无需到期提醒；补入库存后会重新检查。' };
    }
    if (item.expirationDate === undefined || item.expirationDate.length === 0) {
      return { reason: '仍有库存的批次未设置到期日，无需到期提醒。' };
    }
    const parts = item.expirationDate.split('-');
    if (parts.length !== 3) {
      return { reason: '到期日期无效，请检查批次日期后重新同步。' };
    }
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    const expiration = new Date(year, month - 1, day, REMINDER_HOUR, 0, 0, 0);
    if (Number.isNaN(expiration.getTime()) || expiration.getFullYear() !== year ||
      expiration.getMonth() + 1 !== month || expiration.getDate() !== day) {
      return { reason: '到期日期无效，请检查批次日期后重新同步。' };
    }
    const expirationEnd = new Date(year, month - 1, day + 1, 0, 0, 0, 0).getTime();
    if (expirationEnd <= this.clock()) {
      return { reason: '库存已过期，请直接检查物品；不会再创建提前到期提醒。' };
    }
    const reminderDays = item.reminderDays ?? defaultReminderDays;
    expiration.setDate(expiration.getDate() - reminderDays);
    const originalAt = expiration.getTime();
    const reminderAt = originalAt > this.clock() ? originalAt : (Math.floor(this.clock() / MINUTE_MS) + 1) * MINUTE_MS;
    const key = `${item.expirationDate}|${reminderDays}`;
    if (reminderAt >= expirationEnd) {
      return { originalAt: originalAt, key: key, reason: '今天已没有可安排的提醒时间，请直接检查物品。' };
    }
    return { scheduledAt: reminderAt, originalAt: originalAt, key: key };
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}-${this.pad(date.getDate())} ` +
      `${this.pad(date.getHours())}:${this.pad(date.getMinutes())}`;
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
  }

  private createRecord(itemId: string, scheduledAt: number | undefined, systemReminderId: number | undefined,
    status: ReminderRecordStatus, errorSummary?: string, planKey?: string, contentSignature?: string): ReminderRecord {
    return {
      itemId: itemId, scheduledAt: scheduledAt, systemReminderId: systemReminderId, status: status,
      errorSummary: errorSummary, planKey: planKey, contentSignature: contentSignature, updatedAt: this.clock()
    };
  }

  private async saveRecord(record: ReminderRecord): Promise<Result<ReminderRecord>> {
    const result = await this.repository.save(record);
    return result.ok ? result : failure<ReminderRecord>(new AppError(AppErrorCode.DATABASE_WRITE, '保存提醒记录失败，请重试'));
  }

  private async runExclusive<T>(itemId: string, operation: () => Promise<Result<T>>): Promise<Result<T>> {
    const previous = this.operationQueues.get(itemId) ?? Promise.resolve();
    let release: () => void = () => {};
    const current = new Promise<void>((resolve: () => void) => { release = resolve; });
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
