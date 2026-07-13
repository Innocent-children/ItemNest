import { describe, it, expect } from '@ohos/hypium';
import { AppError, AppErrorCode } from '../../../main/ets/common/AppError';
import { failure, Result, success } from '../../../main/ets/common/Result';
import { PreferenceRepositoryPort } from '../../../main/ets/data/repository/PreferenceRepository';
import { ReminderRepositoryPort } from '../../../main/ets/data/repository/ReminderRepository';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ReminderRecord, ReminderRecordStatus } from '../../../main/ets/model/ReminderRecord';
import { DEFAULT_USER_PREFERENCES, UserPreferences } from '../../../main/ets/model/UserPreferences';
import { PreferenceService } from '../../../main/ets/service/PreferenceService';
import { ReminderService } from '../../../main/ets/service/ReminderService';
import { ReminderAdapter } from '../../../main/ets/service/adapter/ReminderAdapter';
import { FakeItemRepository } from './FakeItemRepository';

class FakePreferenceRepository implements PreferenceRepositoryPort {
  failGet: boolean = false;
  value: UserPreferences = DEFAULT_USER_PREFERENCES;

  async get(): Promise<Result<UserPreferences>> {
    if (this.failGet) {
      return failure<UserPreferences>(new AppError(AppErrorCode.PREFERENCE_READ, '读取偏好失败'));
    }
    return success(this.value);
  }

  async save(value: UserPreferences): Promise<Result<UserPreferences>> {
    this.value = value;
    return success(value);
  }
}

class FakeReminderRepository implements ReminderRepositoryPort {
  records: ReminderRecord[] = [];

  async getByItemId(itemId: string): Promise<Result<ReminderRecord | undefined>> {
    return success(this.records.find((record: ReminderRecord) => record.itemId === itemId));
  }

  async save(record: ReminderRecord): Promise<Result<ReminderRecord>> {
    const index = this.records.findIndex((current: ReminderRecord) => current.itemId === record.itemId);
    if (index < 0) {
      this.records.push(record);
    } else {
      this.records[index] = record;
    }
    return success(record);
  }

  async deleteByItemId(itemId: string): Promise<Result<void>> {
    const index = this.records.findIndex((record: ReminderRecord) => record.itemId === itemId);
    if (index >= 0) {
      this.records.splice(index, 1);
    }
    return success<void>(undefined);
  }

  async countScheduledBetween(startAt: number, endAt: number): Promise<Result<number>> {
    return success(this.records.filter((record: ReminderRecord) => record.status === ReminderRecordStatus.SCHEDULED &&
      record.scheduledAt !== undefined && record.scheduledAt >= startAt && record.scheduledAt <= endAt).length);
  }
}

class FakeReminderAdapter implements ReminderAdapter {
  cancelCalls: number[] = [];
  scheduleCalls: number = 0;
  failCancelIds: number[] = [];

  async schedule(item: Item, scheduledAt: number): Promise<Result<number>> {
    this.scheduleCalls += 1;
    return success(100 + this.scheduleCalls);
  }

  async cancel(systemReminderId: number): Promise<Result<void>> {
    this.cancelCalls.push(systemReminderId);
    if (this.failCancelIds.indexOf(systemReminderId) >= 0) {
      return failure<void>(new AppError(AppErrorCode.REMINDER_DISPATCH, '取消失败'));
    }
    return success<void>(undefined);
  }
}

function buildItem(id: string): Item {
  return {
    id: id, name: `物品-${id}`, quantity: 1, unit: ItemUnit.PIECE,
    expirationDate: '2030-01-10', photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
  };
}

function enabledPreferences(): UserPreferences {
  return {
    defaultReminderDays: 7,
    defaultSort: DEFAULT_USER_PREFERENCES.defaultSort,
    showRecentSection: true,
    showExpirySection: true,
    showStockSection: true,
    themeMode: DEFAULT_USER_PREFERENCES.themeMode,
    reminderEnabled: true
  };
}

export default function reminderServiceTest() {
  describe('ReminderService', () => {
    it('偏好读取失败时不会先取消现有系统提醒', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.failGet = true;
      const records = new FakeReminderRepository();
      records.records.push({
        itemId: 'item-1', scheduledAt: 10000, systemReminderId: 42,
        status: ReminderRecordStatus.SCHEDULED, updatedAt: 1
      });
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const result = await service.reconcile(items.items[0]);

      expect(result.ok).assertFalse();
      expect(adapter.cancelCalls.length).assertEqual(0);
      expect(records.records[0].status).assertEqual(ReminderRecordStatus.SCHEDULED);
    });

    it('批量关闭提醒遇到失败仍继续处理其余物品', 0, async () => {
      const preferences = new FakePreferenceRepository();
      const records = new FakeReminderRepository();
      records.records.push({ itemId: 'item-1', systemReminderId: 1, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      records.records.push({ itemId: 'item-2', systemReminderId: 2, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      const adapter = new FakeReminderAdapter();
      adapter.failCancelIds.push(1);
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      items.items.push(buildItem('item-2'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const result = await service.cancelAllForDisabledPreference();

      expect(result.ok).assertFalse();
      expect(adapter.cancelCalls.length).assertEqual(2);
      expect(records.records.find((record: ReminderRecord) => record.itemId === 'item-2')).assertUndefined();
    });

    it('已按相同时间安排时不会重复取消和创建', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const scheduledAt = new Date(2030, 0, 10, 9, 0, 0, 0).getTime() - 7 * 24 * 60 * 60 * 1000;
      records.records.push({
        itemId: 'item-1', scheduledAt: scheduledAt, systemReminderId: 7,
        status: ReminderRecordStatus.SCHEDULED, updatedAt: 1
      });
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const result = await service.reconcile(items.items[0]);

      expect(result.ok).assertTrue();
      expect(adapter.cancelCalls.length).assertEqual(0);
      expect(adapter.scheduleCalls).assertEqual(0);
    });

    it('并发同步同一物品时只创建一个系统提醒', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const results = await Promise.all([
        service.reconcile(items.items[0]),
        service.reconcile(items.items[0])
      ]);

      expect(results.filter((result: Result<ReminderRecord>) => result.ok).length).assertEqual(2);
      expect(adapter.scheduleCalls).assertEqual(1);
      expect(records.records.length).assertEqual(1);
      expect(records.records[0].status).assertEqual(ReminderRecordStatus.SCHEDULED);
      expect(records.records[0].systemReminderId).assertEqual(101);
    });

    it('并发取消同一物品时只取消一次系统提醒', 0, async () => {
      const preferences = new FakePreferenceRepository();
      const records = new FakeReminderRepository();
      records.records.push({
        itemId: 'item-1', scheduledAt: 10000, systemReminderId: 42,
        status: ReminderRecordStatus.SCHEDULED, updatedAt: 1
      });
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const results = await Promise.all([
        service.cancelForItem('item-1'),
        service.cancelForItem('item-1')
      ]);

      expect(results.filter((result: Result<void>) => result.ok).length).assertEqual(2);
      expect(adapter.cancelCalls.length).assertEqual(1);
      expect(adapter.cancelCalls[0]).assertEqual(42);
      expect(records.records.length).assertEqual(0);
    });

    it('同一物品先同步后取消时不会遗留系统提醒', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('item-1'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);

      const reconcilePromise = service.reconcile(items.items[0]);
      const cancelPromise = service.cancelForItem('item-1');
      const reconcileResult = await reconcilePromise;
      const cancelResult = await cancelPromise;

      expect(reconcileResult.ok).assertTrue();
      expect(cancelResult.ok).assertTrue();
      expect(adapter.scheduleCalls).assertEqual(1);
      expect(adapter.cancelCalls.length).assertEqual(1);
      expect(adapter.cancelCalls[0]).assertEqual(101);
      expect(records.records.length).assertEqual(0);
    });
  });
}
