import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { AppServices } from '../service/AppServices';

export default class ItemTraceFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData({ dueSoonCount: '0', todayReminderCount: '0' });
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private async refreshForm(formId: string): Promise<void> {
    try {
      AppServices.configure(this.context);
      const snapshotResult = await AppServices.get().formSnapshot.getSnapshot();
      if (!snapshotResult.ok) {
        return;
      }
      const snapshot = snapshotResult.getData();
      const bindingData = formBindingData.createFormBindingData({
        dueSoonCount: snapshot.dueSoonCount.toString(),
        todayReminderCount: snapshot.todayReminderCount.toString()
      });
      await formProvider.updateForm(formId, bindingData);
    } catch (_) {
      // 卡片刷新失败不影响主应用本地物品管理。
    }
  }
}
