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
    } catch (_) {
      return failure<number>(new AppError(AppErrorCode.REMINDER_DISPATCH, '系统提醒创建失败，请检查通知授权后重试'));
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
