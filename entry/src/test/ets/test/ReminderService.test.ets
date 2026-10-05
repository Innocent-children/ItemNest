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
  activeSaves: number = 0;
  maxConcurrentSaves: number = 0;
  value: UserPreferences = DEFAULT_USER_PREFERENCES;

  async get(): Promise<Result<UserPreferences>> {
    if (this.failGet) {
      return failure<UserPreferences>(new AppError(AppErrorCode.PREFERENCE_READ, '读取偏好失败'));
    }
    return success(this.value);
  }

  async save(value: UserPreferences): Promise<Result<UserPreferences>> {
    this.activeSaves++;
    this.maxConcurrentSaves = Math.max(this.maxConcurrentSaves, this.activeSaves);
    await Promise.resolve();
    this.value = value;
    this.activeSaves--;
    return success(value);
  }
}

class FakeReminderRepository implements ReminderRepositoryPort {
  records: ReminderRecord[] = [];
  failScheduledSaveOnce: boolean = false;

  async getByItemId(itemId: string): Promise<Result<ReminderRecord | undefined>> {
    return success(this.records.find((record: ReminderRecord) => record.itemId === itemId));
  }

  async save(record: ReminderRecord): Promise<Result<ReminderRecord>> {
    if (this.failScheduledSaveOnce && record.status === ReminderRecordStatus.SCHEDULED) {
      this.failScheduledSaveOnce = false;
      return failure<ReminderRecord>(new AppError(AppErrorCode.DATABASE_WRITE, '保存提醒记录失败'));
    }
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
    return success(this.records.filter((record: ReminderRecord) => (record.status === ReminderRecordStatus.SCHEDULED || record.status === ReminderRecordStatus.DUE) &&
      record.scheduledAt !== undefined && record.scheduledAt >= startAt && record.scheduledAt <= endAt).length);
  }
}

class FakeReminderAdapter implements ReminderAdapter {
  cancelCalls: number[] = [];
  scheduleCalls: number = 0;
  failCancelIds: number[] = [];
  permissionDenied: boolean = false;
  failScheduleItemIds: string[] = [];
  scheduledTimes: number[] = [];
  scheduledNames: string[] = [];
  onSchedule: () => void = () => {};

  async checkPermission(): Promise<Result<void>> {
    return this.permissionDenied ? failure<void>(new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED, '系统通知未授权')) :
      success<void>(undefined);
  }

  async schedule(item: Item, scheduledAt: number): Promise<Result<number>> {
    this.scheduleCalls += 1;
    this.scheduledTimes.push(scheduledAt);
    this.scheduledNames.push(item.name);
    this.onSchedule();
    if (this.failScheduleItemIds.indexOf(item.id) >= 0) {
      return failure<number>(new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED, '系统通知未授权，请在设置中管理系统通知授权后重试'));
    }
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
        status: ReminderRecordStatus.SCHEDULED, planKey: '2030-01-10|7',
        contentSignature: '物品-item-1\n2030-01-10', updatedAt: 1
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

    it('已进入提醒期仍安排下一分钟且重复同步不延后或重发', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('near'));
      let now = new Date(2030, 0, 8, 10, 0, 30).getTime();
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => now);

      const first = await service.reconcileLatest('near');
      const expected = new Date(2030, 0, 8, 10, 1, 0).getTime();
      expect(first.ok).assertTrue();
      expect(first.getData().scheduledAt).assertEqual(expected);
      expect(service.describeRecord(first.getData()).includes('原计划提醒时间已过')).assertTrue();
      now += 10000;
      await service.reconcileLatest('near');
      expect(adapter.scheduleCalls).assertEqual(1);
      expect(records.records[0].scheduledAt).assertEqual(expected);
      now = expected + 1000;
      const afterTime = await service.reconcileLatest('near');
      expect(afterTime.getData().status).assertEqual(ReminderRecordStatus.DUE);
      expect(service.describeRecord(afterTime.getData()).includes('实际通知是否送达由系统决定')).assertTrue();
      await service.reconcileLatest('near');
      expect(adapter.scheduleCalls).assertEqual(1);
    });

    it('读取状态后不会继续把过去的计划显示为已安排', 0, async () => {
      const preferences = new FakePreferenceRepository();
      const records = new FakeReminderRepository();
      records.records.push({ itemId: 'old', scheduledAt: 1000, systemReminderId: 10,
        status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      const service = new ReminderService(records, new PreferenceService(preferences), new FakeReminderAdapter(),
        new FakeItemRepository(), () => 2000);
      const result = await service.getRecord('old');
      expect(result.ok).assertTrue();
      expect(result.getData()?.status).assertEqual(ReminderRecordStatus.DUE);
      expect(records.records[0].status).assertEqual(ReminderRecordStatus.DUE);
      expect((await records.countScheduledBetween(0, 3000)).getData()).assertEqual(1);
    });

    it('同一计划重命名会更新通知内容但保留时间', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('rename'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items,
        () => new Date(2030, 0, 1, 10, 0, 0).getTime());
      const first = await service.reconcileLatest('rename');
      items.items[0].name = '新的名字';
      const second = await service.reconcileLatest('rename');
      expect(second.ok).assertTrue();
      expect(adapter.scheduleCalls).assertEqual(2);
      expect(adapter.cancelCalls[0]).assertEqual(first.getData().systemReminderId);
      expect(second.getData().scheduledAt).assertEqual(first.getData().scheduledAt);
      expect(adapter.scheduledNames[1]).assertEqual('新的名字');
    });

    it('无库存和已过期会取消旧提醒并给出不同原因', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      const empty = buildItem('empty');
      empty.quantity = 0;
      const expired = buildItem('expired');
      expired.expirationDate = '2029-12-31';
      items.items.push(empty, expired);
      records.records.push({ itemId: empty.id, systemReminderId: 1, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      records.records.push({ itemId: expired.id, systemReminderId: 2, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items,
        () => new Date(2030, 0, 1, 10, 0, 0).getTime());
      const emptyResult = await service.reconcileLatest(empty.id);
      const expiredResult = await service.reconcileLatest(expired.id);
      expect(adapter.scheduleCalls).assertEqual(0);
      expect(adapter.cancelCalls.length).assertEqual(2);
      expect(service.describeRecord(emptyResult.getData()).includes('库存为 0')).assertTrue();
      expect(service.describeRecord(expiredResult.getData()).includes('已过期')).assertTrue();
    });

    it('到期日当天仍可提醒且不会把提醒安排到日期之后', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('last-day'));
      let now = new Date(2030, 0, 10, 10, 0, 30).getTime();
      const service = new ReminderService(new FakeReminderRepository(), new PreferenceService(preferences), adapter,
        items, () => now);
      const valid = await service.reconcileLatest('last-day');
      expect(valid.getData().scheduledAt).assertEqual(new Date(2030, 0, 10, 10, 1, 0).getTime());
      now = new Date(2030, 0, 10, 23, 59, 30).getTime();
      const tooLateItems = new FakeItemRepository();
      tooLateItems.items.push(buildItem('late'));
      const tooLate = new ReminderService(new FakeReminderRepository(), new PreferenceService(preferences), adapter,
        tooLateItems, () => now);
      const late = await tooLate.reconcileLatest('late');
      expect(late.getData().status).assertEqual(ReminderRecordStatus.NOT_REQUIRED);
      expect(late.getData().errorSummary?.includes('今天已没有')).assertTrue();
      expect(adapter.scheduleCalls).assertEqual(1);
    });

    it('设置批量同步已有物品并在单项未授权时继续其余物品', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      adapter.failScheduleItemIds.push('denied');
      const items = new FakeItemRepository();
      const noDate = buildItem('no-date');
      noDate.expirationDate = undefined;
      items.items.push(buildItem('denied'), buildItem('ok'), noDate);
      const preferenceService = new PreferenceService(preferences);
      const service = new ReminderService(records, preferenceService, adapter, items,
        () => new Date(2030, 0, 1, 10, 0, 0).getTime());
      const result = await service.reconcileAll();
      expect(result.ok).assertTrue();
      expect(result.getData().scheduled).assertEqual(1);
      expect(result.getData().notRequired).assertEqual(1);
      expect(result.getData().failed).assertEqual(1);
      expect(service.describeSummary(result.getData()).includes('物品-denied：系统通知未授权')).assertTrue();
      adapter.failScheduleItemIds = [];
      const retry = await service.reconcileAll();
      expect(retry.getData().failed).assertEqual(0);
      expect(retry.getData().scheduled).assertEqual(2);
      // The existing successful item was not created again.
      expect(adapter.scheduleCalls).assertEqual(3);
      const changed = enabledPreferences();
      changed.defaultReminderDays = 1;
      await preferenceService.save(changed);
      await service.reconcileAll();
      expect(records.records.find((record: ReminderRecord) => record.itemId === 'ok')?.scheduledAt)
        .assertEqual(new Date(2030, 0, 9, 9, 0, 0).getTime());
    });

    it('关闭提醒批量取消失败可定位和重试且保留其余结果', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      preferences.value.reminderEnabled = false;
      const records = new FakeReminderRepository();
      records.records.push({ itemId: 'one', systemReminderId: 1, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      records.records.push({ itemId: 'two', systemReminderId: 2, status: ReminderRecordStatus.SCHEDULED, updatedAt: 1 });
      const adapter = new FakeReminderAdapter();
      adapter.failCancelIds.push(1);
      const items = new FakeItemRepository();
      items.items.push(buildItem('one'), buildItem('two'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);
      const first = await service.reconcileAll();
      expect(first.getData().failed).assertEqual(1);
      expect(first.getData().notRequired).assertEqual(1);
      expect(records.records.find((record: ReminderRecord) => record.itemId === 'one')?.systemReminderId).assertEqual(1);
      adapter.failCancelIds = [];
      const retry = await service.reconcileAll();
      expect(retry.getData().failed).assertEqual(0);
      expect(adapter.scheduleCalls).assertEqual(0);
      expect(adapter.cancelCalls.length).assertEqual(3);
      expect(service.describeRecord(records.records[0]).includes('未启用')).assertTrue();
    });

    it('并发最新同步在排队后读取更新后的批次日期', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('latest'));
      adapter.onSchedule = () => {
        if (adapter.scheduleCalls === 1) {
          items.items[0].expirationDate = '2030-02-10';
        }
      };
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items,
        () => new Date(2030, 0, 1, 10, 0, 0).getTime());
      const results = await Promise.all([service.reconcileLatest('latest'), service.reconcileLatest('latest')]);
      expect(results[0].ok && results[1].ok).assertTrue();
      expect(adapter.scheduleCalls).assertEqual(2);
      expect(records.records[0].planKey).assertEqual('2030-02-10|7');
      expect(records.records[0].scheduledAt).assertEqual(new Date(2030, 1, 3, 9, 0, 0).getTime());
    });

    it('系统创建成功但记录保存失败会撤销提醒并可再次同步', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      records.failScheduledSaveOnce = true;
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('save-fail'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);
      const first = await service.reconcileLatest('save-fail');
      expect(first.ok).assertFalse();
      expect(adapter.cancelCalls[0]).assertEqual(101);
      expect(records.records[0].systemReminderId).assertUndefined();
      const retry = await service.reconcileLatest('save-fail');
      expect(retry.ok).assertTrue();
      expect(records.records[0].systemReminderId).assertEqual(102);
    });

    it('并发设置保存不会交错读取且同步使用最终已保存设置', 0, async () => {
      const repository = new FakePreferenceRepository();
      const service = new PreferenceService(repository);
      const first = enabledPreferences();
      first.defaultReminderDays = 3;
      const second = enabledPreferences();
      second.defaultReminderDays = 1;
      const firstSave = service.save(first);
      const secondSave = service.save(second);
      const read = service.get();
      await Promise.all([firstSave, secondSave]);
      const result = await read;
      expect(repository.maxConcurrentSaves).assertEqual(1);
      expect(result.getData().defaultReminderDays).assertEqual(1);
    });

    it('撤销通知授权不会把已有未来提醒误报为同步成功且重试可恢复', 0, async () => {
      const preferences = new FakePreferenceRepository();
      preferences.value = enabledPreferences();
      const records = new FakeReminderRepository();
      const adapter = new FakeReminderAdapter();
      const items = new FakeItemRepository();
      items.items.push(buildItem('revoked'));
      const service = new ReminderService(records, new PreferenceService(preferences), adapter, items, () => 1000);
      const first = await service.reconcileLatest('revoked');
      adapter.permissionDenied = true;
      const denied = await service.reconcileLatest('revoked');
      expect(denied.ok).assertFalse();
      expect(records.records[0].status).assertEqual(ReminderRecordStatus.FAILED);
      expect(records.records[0].systemReminderId).assertEqual(first.getData().systemReminderId);
      expect(adapter.cancelCalls.length).assertEqual(0);
      expect(service.describeRecord(records.records[0]).includes('未授权')).assertTrue();
      adapter.permissionDenied = false;
      const retry = await service.reconcileLatest('revoked');
      expect(retry.ok).assertTrue();
      expect(adapter.cancelCalls.length).assertEqual(1);
      expect(adapter.scheduleCalls).assertEqual(2);
    });
  });
}
