import { describe, it, expect } from '@ohos/hypium';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { AppErrorCode } from '../../../main/ets/common/AppError';
import { reminderPublishFailure } from '../../../main/ets/service/ReminderFailure';

export default function reminderRecoveryDeviceTest() {
  describe('ReminderRecoveryDevice', () => {
    it('真实提醒发布成功可撤销，受限时准确报告且不冒充成功', 0, async () => {
      const existing = await reminderAgentManager.getValidReminders();
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.print('ItemNestReminderAudit permission=' + await notificationManager.isNotificationEnabled() + ' count=' + existing.length);
      let created: number | undefined = undefined;
      try {
        const request: reminderAgentManager.ReminderRequestTimer = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
          triggerTimeInSeconds: 600, title: 'ItemNest 提醒测试', content: '独立测试，完成后撤销',
          wantAgent: { pkgName: 'com.imotong.itemnest', abilityName: 'EntryAbility' }
        };
        created = await reminderAgentManager.publishReminder(request);
        await delegator.print('ItemNestReminderAudit created=' + created);
        expect(created !== undefined).assertTrue();
      } catch (error) {
        const code = (error as BusinessError).code;
        await delegator.print('ItemNestReminderAudit blocked=' + code + ' count=' + existing.length);
        expect(code).assertEqual(1700002);
        const failure = reminderPublishFailure(code, existing.length);
        expect(failure.code).assertEqual(AppErrorCode.REMINDER_DISPATCH);
        expect(failure.message.includes('已保留')).assertTrue();
        if (existing.length === 0) { expect(failure.message.includes('清理')).assertFalse(); }
      } finally {
        if (created !== undefined) { await reminderAgentManager.cancelReminder(created); }
      }
    });
  });
}
