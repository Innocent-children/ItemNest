import { UIAbility, Want, AbilityConstant, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { commonEventManager } from '@kit.BasicServicesKit';
import { ShareService } from '../services/ShareService';
import { readApplicationIcon } from '../services/ApplicationIcon';

export default class EntryAbility extends UIAbility {
  private timeSubscriber?: commonEventManager.CommonEventSubscriber;
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.receive(want);
    commonEventManager.createSubscriber({ events: [commonEventManager.Support.COMMON_EVENT_TIME_CHANGED, commonEventManager.Support.COMMON_EVENT_DATE_CHANGED, commonEventManager.Support.COMMON_EVENT_TIMEZONE_CHANGED] }).then((subscriber) => {
      this.timeSubscriber = subscriber;
      commonEventManager.subscribe(subscriber, (error) => { if (!error) AppStorage.setOrCreate('foregroundAt', Date.now()); });
    }).catch(() => {});
  }
  onConfigurationUpdate(configuration: Configuration): void { AppStorage.setOrCreate('fontScale', configuration.fontSizeScale ?? 1); }
  onDestroy(): void { if (this.timeSubscriber) commonEventManager.unsubscribe(this.timeSubscriber); }
  onNewWant(want: Want): void {
    this.receive(want);
  }
  private receive(want: Want): void {
    if(want.action === 'ohos.want.action.sendData') {
      ShareService.receive(this.context,want).catch((error:Error)=>AppStorage.setOrCreate('entryError',error.message));
    } else {
      AppStorage.setOrCreate('entryItemId',String(want.parameters?.itemId ?? ''));
      AppStorage.setOrCreate('entryAction',String(want.parameters?.action ?? ''));
    }
  }
  async onWindowStageCreate(stage: window.WindowStage): Promise<void> {
    const icon = await readApplicationIcon().catch(() => '');
    const storage = new LocalStorage();
    storage.setOrCreate('launchIcon', icon);
    stage.loadContent('pages/Index', storage);
  }
  onBackground(): void {
    AppStorage.setOrCreate('backgroundAt', Date.now());
  }
  onForeground(): void {
    AppStorage.setOrCreate('foregroundAt', Date.now());
  }
}
