import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { AppEventBus } from '../common/AppEventBus';
import { AppServices } from '../service/AppServices';

export default class ItemTraceFormAbility extends FormExtensionAbility {
  private formIds: Set<string> = new Set<string>();
  private dataListenerId: number = 0;
  private refreshRunning: boolean = false;
  private refreshPending: boolean = false;

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formIdValue = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    if (formIdValue !== undefined) {
      const formId = formIdValue.toString();
      this.formIds.add(formId);
      this.ensureDataSubscription();
      this.refreshAllForms();
    }
    return formBindingData.createFormBindingData({ dueSoonCount: '—', todayReminderCount: '—' });
  }

  onUpdateForm(formId: string): void {
    this.formIds.add(formId);
    this.ensureDataSubscription();
    this.refreshAllForms();
  }

  onRemoveForm(formId: string): void {
    this.formIds.delete(formId);
    if (this.formIds.size === 0) {
      this.releaseDataSubscription();
    }
  }

  onStop(): void {
    this.releaseDataSubscription();
    this.refreshPending = false;
    this.formIds.clear();
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private ensureDataSubscription(): void {
    if (this.dataListenerId > 0) {
      return;
    }
    this.dataListenerId = AppEventBus.subscribeDataChanged(() => this.refreshAllForms());
    this.restoreRunningForms();
  }

  private releaseDataSubscription(): void {
    if (this.dataListenerId > 0) {
      AppEventBus.unsubscribeDataChanged(this.dataListenerId);
      this.dataListenerId = 0;
    }
  }

  private refreshAllForms(): void {
    this.refreshPending = true;
    this.drainFormRefreshes();
  }

  private async restoreRunningForms(): Promise<void> {
    try {
      const runningForms = await formProvider.getPublishedRunningFormInfos();
      for (let index = 0; index < runningForms.length; index++) {
        const runningForm = runningForms[index];
        if (runningForm.moduleName === 'entry' && runningForm.abilityName === 'ItemTraceFormAbility') {
          this.formIds.add(runningForm.formId);
        }
      }
      this.refreshAllForms();
    } catch (_) {
      // 当前 onAdd/onUpdate 收到的 formId 仍可正常刷新；系统查询失败时等待下一次回调重试。
    }
  }

  private async drainFormRefreshes(): Promise<void> {
    if (this.refreshRunning) {
      return;
    }
    this.refreshRunning = true;
    try {
      while (this.refreshPending) {
        this.refreshPending = false;
        await this.refreshAllFormsOnce();
      }
    } finally {
      this.refreshRunning = false;
    }
  }

  private async refreshAllFormsOnce(): Promise<void> {
    try {
      AppServices.configure(this.context);
      const snapshotResult = await AppServices.get().formSnapshot.getSnapshot();
      const snapshot = snapshotResult.ok ? snapshotResult.getData() : AppServices.get().formSnapshot.failedSnapshot();
      const bindingData = formBindingData.createFormBindingData(snapshot);
      const formIds = Array.from(this.formIds);
      for (let index = 0; index < formIds.length; index++) {
        try {
          await formProvider.updateForm(formIds[index], bindingData);
        } catch (_) {
          // 单个卡片失效不阻断其余卡片刷新。
        }
      }
    } catch (_) {
      // 卡片刷新失败不影响主应用本地物品管理。
    }
  }
}
