import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { Item } from '../../model/Item';

export interface ReminderAdapter {
  schedule(item: Item, scheduledAt: number): Promise<Result<number>>;
  cancel(systemReminderId: number): Promise<Result<void>>;
}

export class SystemReminderAdapter implements ReminderAdapter {
  async schedule(item: Item, scheduledAt: number): Promise<Result<number>> {
    try {
      if (!await notificationManager.isNotificationEnabled()) {
        return failure<number>(new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED,
          '系统通知未授权，请在设置中管理系统通知授权后重试'));
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
        title: 'ItemTrace 到期提醒',
        content: `“${item.name}”即将到期，请及时检查。`,
        tapDismissed: true
      };
      return success<number>(await reminderAgentManager.publishReminder(request));
    } catch (error) {
      const code = (error as BusinessError).code;
      const message = code === 201 ? '设备未授予代理提醒权限，请检查系统权限' :
        code === 1700001 ? '系统通知未授权，请在设置中管理系统通知授权后重试' :
          code === 1700002 ? '系统提醒数量已达上限，请清理已有提醒后重试' :
            '系统提醒创建失败，请稍后重试';
      return failure<number>(new AppError(code === 201 || code === 1700001
        ? AppErrorCode.SYSTEM_PERMISSION_DENIED : AppErrorCode.REMINDER_DISPATCH, message));
    }
  }

  async cancel(systemReminderId: number): Promise<Result<void>> {
    try {
      await reminderAgentManager.cancelReminder(systemReminderId);
      return success<void>(undefined);
    } catch (_) {
      return failure<void>(new AppError(AppErrorCode.REMINDER_DISPATCH, '系统提醒取消失败，请稍后重试'));
    }
  }
}
