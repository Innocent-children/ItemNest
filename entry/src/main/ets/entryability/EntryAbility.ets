import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { formBindingData, formProvider } from '@kit.FormKit';
import { AppServices } from '../service/AppServices';
import { AppEventBus } from '../common/AppEventBus';
import { ThemeMode } from '../model/UserPreferences';

const DOMAIN = 0x0000;
const QUICK_ADD_FORM_SOURCE = 'itemtrace-form-quick-add';

interface SafeAreaInsets {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window;
  private avoidAreaChangeCallback?: (options: window.AvoidAreaOptions) => void;
  private formRefreshListenerId: number = 0;
  private formRefreshRunning: boolean = false;
  private formRefreshPending: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppServices.configure(this.context);
    this.formRefreshListenerId = AppEventBus.subscribeDataChanged(() => this.refreshRunningForms());
    this.handleFormLinkWant(want);
    this.applyTheme();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    if (this.formRefreshListenerId > 0) {
      AppEventBus.unsubscribeDataChanged(this.formRefreshListenerId);
      this.formRefreshListenerId = 0;
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.loadMainContent(windowStage);
  }

  private async loadMainContent(windowStage: window.WindowStage): Promise<void> {
    await AppServices.get().photoMaintenance.cleanupOrphans();
    await this.applyImmersiveWindow(windowStage);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      if (this.mainWindow !== undefined) {
        this.updateSafeArea(this.mainWindow);
      }
    });
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== undefined && this.avoidAreaChangeCallback !== undefined) {
      try {
        this.mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      } catch (_) {
      }
    }
    this.avoidAreaChangeCallback = undefined;
    this.mainWindow = undefined;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.refreshForegroundAppearance();
    AppEventBus.notifyDataChanged();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleFormLinkWant(want);
  }

  private async applyTheme(): Promise<void> {
    try {
      const result = await AppServices.get().preferences.get();
      if (!result.ok) {
        return;
      }
      const themeMode = result.getData().themeMode;
      const colorMode = themeMode === ThemeMode.DARK
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : themeMode === ThemeMode.LIGHT
          ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
          : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      this.context.getApplicationContext().setColorMode(colorMode);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async refreshForegroundAppearance(): Promise<void> {
    await this.applyTheme();
    if (this.mainWindow === undefined) {
      return;
    }
    try {
      let themeMode = ThemeMode.SYSTEM;
      const result = await AppServices.get().preferences.get();
      if (result.ok) {
        themeMode = result.getData().themeMode;
      }
      await this.applySystemBarStyle(this.mainWindow, themeMode);
      this.updateSafeArea(this.mainWindow);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to refresh foreground appearance. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async applyImmersiveWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      let themeMode = ThemeMode.SYSTEM;
      const result = await AppServices.get().preferences.get();
      if (result.ok) {
        themeMode = result.getData().themeMode;
      }
      const mainWindow = await windowStage.getMainWindow();
      this.mainWindow = mainWindow;
      await mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setImmersiveModeEnabledState(true);
      await this.applySystemBarStyle(mainWindow, themeMode);
      this.updateSafeArea(mainWindow);
      this.avoidAreaChangeCallback = (options: window.AvoidAreaOptions): void => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM ||
          options.type === window.AvoidAreaType.TYPE_CUTOUT ||
          options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.updateSafeArea(mainWindow);
        }
      };
      mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply immersive window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async applySystemBarStyle(mainWindow: window.Window, themeMode: ThemeMode): Promise<void> {
    const useLightIcon = this.shouldUseLightSystemBarIcon(themeMode);
    const contentColor = useLightIcon ? '#FFFFFF' : '#000000';
    try {
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: useLightIcon,
        isNavigationBarLightIcon: useLightIcon,
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply system bar style. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private updateSafeArea(mainWindow: window.Window): void {
    try {
      const insets: SafeAreaInsets = { top: 0, right: 0, bottom: 0, left: 0 };
      this.mergeAvoidArea(mainWindow, window.AvoidAreaType.TYPE_SYSTEM, insets);
      this.mergeAvoidArea(mainWindow, window.AvoidAreaType.TYPE_CUTOUT, insets);
      this.mergeAvoidArea(mainWindow, window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR, insets);
      AppStorage.setOrCreate<number>('itemtrace.safeAreaTop', insets.top);
      AppStorage.setOrCreate<number>('itemtrace.safeAreaRight', insets.right);
      AppStorage.setOrCreate<number>('itemtrace.safeAreaBottom', insets.bottom);
      AppStorage.setOrCreate<number>('itemtrace.safeAreaLeft', insets.left);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to update safe area. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private mergeAvoidArea(mainWindow: window.Window, type: window.AvoidAreaType, insets: SafeAreaInsets): void {
    try {
      const avoidArea = mainWindow.getWindowAvoidArea(type);
      const uiContext = mainWindow.getUIContext();
      insets.top = Math.max(insets.top, Math.max(0, uiContext.px2vp(avoidArea.topRect.height)));
      insets.right = Math.max(insets.right, Math.max(0, uiContext.px2vp(avoidArea.rightRect.width)));
      insets.bottom = Math.max(insets.bottom, Math.max(0, uiContext.px2vp(avoidArea.bottomRect.height)));
      insets.left = Math.max(insets.left, Math.max(0, uiContext.px2vp(avoidArea.leftRect.width)));
    } catch (_) {
      // 某些设备不提供特定 avoid area，保留其他类型的有效值。
    }
  }

  private shouldUseLightSystemBarIcon(themeMode: ThemeMode): boolean {
    if (themeMode === ThemeMode.DARK) {
      return true;
    }
    if (themeMode === ThemeMode.LIGHT) {
      return false;
    }
    return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private async refreshRunningForms(): Promise<void> {
    this.formRefreshPending = true;
    if (this.formRefreshRunning) {
      return;
    }
    this.formRefreshRunning = true;
    try {
      while (this.formRefreshPending) {
        this.formRefreshPending = false;
        await this.refreshRunningFormsOnce();
      }
    } finally {
      this.formRefreshRunning = false;
    }
  }

  private async refreshRunningFormsOnce(): Promise<void> {
    try {
      const runningForms = await formProvider.getPublishedRunningFormInfos();
      const itemTraceFormIds: string[] = [];
      for (let index = 0; index < runningForms.length; index++) {
        const runningForm = runningForms[index];
        if (runningForm.moduleName === 'entry' && runningForm.abilityName === 'ItemTraceFormAbility') {
          itemTraceFormIds.push(runningForm.formId);
        }
      }
      if (itemTraceFormIds.length === 0) {
        return;
      }
      const snapshotResult = await AppServices.get().formSnapshot.getSnapshot();
      if (!snapshotResult.ok) {
        return;
      }
      const snapshot = snapshotResult.getData();
      const bindingData = formBindingData.createFormBindingData({
        dueSoonCount: snapshot.dueSoonCount.toString(),
        todayReminderCount: snapshot.todayReminderCount.toString()
      });
      for (let index = 0; index < itemTraceFormIds.length; index++) {
        try {
          await formProvider.updateForm(itemTraceFormIds[index], bindingData);
        } catch (_) {
          // 单个卡片失效不阻断其他卡片刷新。
        }
      }
    } catch (_) {
      // 卡片刷新是尽力操作，不影响主应用的数据写入结果。
    }
  }

  private handleFormLinkWant(want: Want): void {
    const source = want.parameters?.['source'];
    if (source === QUICK_ADD_FORM_SOURCE) {
      AppStorage.setOrCreate<string>('itemtrace.quickAddRequest', `${QUICK_ADD_FORM_SOURCE}:${Date.now()}`);
    }
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
