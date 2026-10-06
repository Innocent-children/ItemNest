import { wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { SystemFeatureService } from './SystemFeatureService';

/**
 * 页面进度始终可用；实况窗创建失败不影响文件操作。提交恢复事务后禁止取消。
 */
export class BackupProgressService {
  private settings: SystemFeatureService;
  private active: boolean = false;
  private cancelled: boolean = false;
  private cancellable: boolean = true;
  private startedAt: number = 0;
  private lastPublished: number = 0;
  private suspendId: number = -1;
  private live?: liveViewManager.LiveView;
  private liveAllowed: boolean = false;
  private liveFailed: boolean = false;

  constructor(settings: SystemFeatureService) { this.settings = settings; }

  async begin(title: string): Promise<void> {
    if (this.active) { throw new Error('已有备份或恢复正在执行'); }
    this.active = true; this.cancelled = false; this.cancellable = true; this.live = undefined;
    this.liveFailed = false; this.startedAt = Date.now(); this.lastPublished = 0;
    AppStorage.setOrCreate<boolean>('itemnest.backupActive', true);
    AppStorage.setOrCreate<boolean>('itemnest.backupCancellable', true);
    AppStorage.setOrCreate<string>('itemnest.backupProgress', title);
    AppStorage.setOrCreate<number>('itemnest.backupPercent', 0);
    try { this.liveAllowed = (await this.settings.get()).liveViewEnabled; } catch (_) { this.liveAllowed = false; }
    try {
      this.suspendId = backgroundTaskManager.requestSuspendDelay('完成物品备份或恢复', () => {
        if (this.cancellable) { this.cancel(); }
      }).requestId;
    } catch (_) { this.suspendId = -1; }
  }

  cancel(): void {
    if (this.active && this.cancellable) {
      this.cancelled = true;
      AppStorage.setOrCreate<string>('itemnest.backupProgress', '正在取消并清理临时数据…');
    }
  }

  check(): void {
    if (this.cancelled) { throw new Error('操作已取消'); }
  }

  seal(): void {
    this.check(); this.cancellable = false;
    AppStorage.setOrCreate<boolean>('itemnest.backupCancellable', false);
  }

  async report(title: string, completed: number, total: number): Promise<void> {
    this.check();
    const percent = total > 0 ? Math.min(100, Math.floor(completed * 100 / total)) : 0;
    const text = title + (total > 0 ? ' · ' + completed + ' / ' + total : '');
    AppStorage.setOrCreate<string>('itemnest.backupProgress', text);
    AppStorage.setOrCreate<number>('itemnest.backupPercent', percent);
    if (!this.liveAllowed || this.liveFailed || Date.now() - this.startedAt < 1500 || Date.now() - this.lastPublished < 1000) { return; }
    this.lastPublished = Date.now();
    try {
      if (this.live === undefined) {
        if (!await liveViewManager.isLiveViewEnabled()) { this.liveFailed = true; return; }
        const target = await wantAgent.getWantAgent({ wants: [{ bundleName: 'com.imotong.itemnest', abilityName: 'EntryAbility',
          uri: 'itemnest://function/backup' }], operationType: wantAgent.OperationType.START_ABILITY, requestCode: 71,
          wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG] });
        const view: liveViewManager.LiveView = { id: 7101, event: 'PROGRESS', sequence: 1,
          lifeCycleMode: liveViewManager.LifeCycleMode.AUTO_STOP_WHEN_APP_TERMINATE,
          liveViewData: { primary: { title: '物品备份与恢复', content: [{ text: text }], clickAction: target },
            capsule: { type: liveViewManager.CapsuleType.CAPSULE_TYPE_PROGRESS, status: 1, max: 100, progress: percent, content: title } } };
        const started = await liveViewManager.startLiveView(view);
        if (started.resultCode !== 0) { this.liveFailed = true; return; }
        this.live = view;
      } else {
        this.live.sequence = (this.live.sequence ?? 0) + 1;
        this.live.liveViewData.primary.content = [{ text: text }];
        this.live.liveViewData.capsule = { type: liveViewManager.CapsuleType.CAPSULE_TYPE_PROGRESS,
          status: 1, max: 100, progress: percent, content: title };
        const updated = await liveViewManager.updateLiveView(this.live);
        if (updated.resultCode !== 0) { this.liveFailed = true; }
      }
    } catch (_) { this.liveFailed = true; }
  }

  async finish(message: string): Promise<void> {
    try {
      if (this.live !== undefined) {
        this.live.sequence = (this.live.sequence ?? 0) + 1;
        this.live.liveViewData.primary.content = [{ text: message }];
        this.live.liveViewData.primary.keepTime = 0;
        this.live.liveViewData.capsule = { type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT, status: -1, content: message };
        await liveViewManager.stopLiveView(this.live);
      }
    } catch (_) {
      // 进程结束时由系统结束本地实况窗。
    } finally {
      if (this.suspendId >= 0) { try { backgroundTaskManager.cancelSuspendDelay(this.suspendId); } catch (_) {} }
      this.suspendId = -1; this.live = undefined; this.active = false;
      AppStorage.setOrCreate<boolean>('itemnest.backupActive', false);
      AppStorage.setOrCreate<boolean>('itemnest.backupCancellable', false);
      AppStorage.setOrCreate<string>('itemnest.backupProgress', this.cancelled ? '操作已取消' : message);
    }
  }
}
