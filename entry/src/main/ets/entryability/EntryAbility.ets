import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, window } from '@kit.ArkUI';
import { AppServices } from '../service/AppServices';
import { ThemeMode } from '../model/UserPreferences';
import { RouteName } from '../navigation/RouteName';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private pageContentLoaded: boolean = false;
  private pendingFormQuickAdd: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppServices.configure(this.context);
    this.handleFormLinkWant(want);
    this.applyTheme();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.loadMainContent(windowStage);
  }

  private async loadMainContent(windowStage: window.WindowStage): Promise<void> {
    await this.applyImmersiveWindow(windowStage);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.pageContentLoaded = true;
      this.openFormQuickAddIfNeeded();
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    this.applyTheme();
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

  private async applyImmersiveWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      let themeMode = ThemeMode.SYSTEM;
      const result = await AppServices.get().preferences.get();
      if (result.ok) {
        themeMode = result.getData().themeMode;
      }
      const useLightIcon = this.shouldUseLightSystemBarIcon(themeMode);
      const contentColor = useLightIcon ? '#FFFFFF' : '#000000';
      const mainWindow = await windowStage.getMainWindow();
      await mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setImmersiveModeEnabledState(true);
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: useLightIcon,
        isNavigationBarLightIcon: useLightIcon,
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
      this.updateSafeArea(mainWindow);
      mainWindow.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM) {
          this.updateSafeAreaFromArea(mainWindow, options.area);
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply immersive window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private updateSafeArea(mainWindow: window.Window): void {
    try {
      const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.updateSafeAreaFromArea(mainWindow, avoidArea);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to update safe area. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private updateSafeAreaFromArea(mainWindow: window.Window, avoidArea: window.AvoidArea): void {
    try {
      const uiContext = mainWindow.getUIContext();
      const top = Math.max(0, uiContext.px2vp(avoidArea.topRect.height));
      const bottom = Math.max(0, uiContext.px2vp(avoidArea.bottomRect.height));
      AppStorage.setOrCreate<number>('itemtrace.safeAreaTop', top);
      AppStorage.setOrCreate<number>('itemtrace.safeAreaBottom', bottom);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply safe area. Cause: %{public}s', JSON.stringify(err));
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

  private handleFormLinkWant(want: Want): void {
    const source = want.parameters?.['source'];
    if (source === 'itemtrace-form-quick-add') {
      this.pendingFormQuickAdd = true;
      this.openFormQuickAddIfNeeded();
    }
  }

  private openFormQuickAddIfNeeded(): void {
    if (!this.pendingFormQuickAdd || !this.pageContentLoaded) {
      return;
    }
    this.pendingFormQuickAdd = false;
    router.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to open quick-add form. Cause: %{public}s', err.message);
    });
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
