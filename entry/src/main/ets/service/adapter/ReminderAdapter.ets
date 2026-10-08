import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { Item } from '../../model/Item';
import { reminderPublishFailure } from '../ReminderFailure';

export interface ReminderAdapter {
  checkPermission?(): Promise<Result<void>>;
  schedule(item: Item, scheduledAt: number): Promise<Result<number>>;
  cancel(systemReminderId: number): Promise<Result<void>>;
}

export class SystemReminderAdapter implements ReminderAdapter {
  async checkPermission(): Promise<Result<void>> {
    try {
      return await notificationManager.isNotificationEnabled() ? success<void>(undefined) :
        failure<void>(new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED,
          '系统通知未授权，请在设置中管理系统通知授权后重试'));
    } catch (_) {
      return failure<void>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '暂时无法读取系统通知授权状态，请稍后重试'));
    }
  }

  async schedule(item: Item, scheduledAt: number): Promise<Result<number>> {
    try {
      const permission = await this.checkPermission();
      if (!permission.ok) {
        return failure<number>(permission.getError());
      }
      const date = new Date(scheduledAt);
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: {
          year: date.getFullYear(),
          month: date.getMonth() + 1,
          day: date.getDate(),
          hour: date.getHours(),
          minute: date.getMinutes(),
          second: 0
        },
        title: '物品到期提醒',
        wantAgent: { pkgName: 'com.imotong.itemnest', abilityName: 'EntryAbility',
          uri: 'itemnest://item/' + encodeURIComponent(item.id) },
        content: `“${item.name}”到期日为 ${item.expirationDate ?? '未设置'}，请及时检查。${item.activeLocationPaths?.length ? '位置：' + item.activeLocationPaths.join('、') : item.locationPath ? '位置：' + item.locationPath : ''}`,
        tapDismissed: true
      };
      return success<number>(await reminderAgentManager.publishReminder(request));
    } catch (error) {
      const code = (error as BusinessError).code;
      let validCount: number | undefined = undefined;
      if (code === 1700002) {
        try { validCount = (await reminderAgentManager.getValidReminders()).length; } catch (_) {}
      }
      return failure<number>(reminderPublishFailure(code, validCount));
    }
  }

  async cancel(systemReminderId: number): Promise<Result<void>> {
    try {
      await reminderAgentManager.cancelReminder(systemReminderId);
      return success<void>(undefined);
    } catch (error) {
      if ((error as BusinessError).code === 1700003) {
        // Already expired or removed by the system; there is nothing left to cancel.
        return success<void>(undefined);
      }
      return failure<void>(new AppError(AppErrorCode.REMINDER_DISPATCH, '系统提醒取消失败，请稍后重试'));
    }
  }
}
