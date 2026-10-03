import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { LoadingState } from '../components/LoadingState';
import { MainEntryBar } from '../components/MainEntryBar';
import { AppEventBus } from '../common/AppEventBus';
import { ItemSortMode, ThemeMode, UserPreferences } from '../model/UserPreferences';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Component
export struct SettingsPage {
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private defaultReminderDays: string = '7';
  @State private defaultSort: ItemSortMode = ItemSortMode.UPDATED_DESC;
  @State private showRecentSection: boolean = true;
  @State private showExpirySection: boolean = true;
  @State private showStockSection: boolean = true;
  @State private themeMode: ThemeMode = ThemeMode.SYSTEM;
  @State private reminderEnabled: boolean = false;
  @State private persistedReminderEnabled: boolean = false;
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private errorMessage: string = '';
  @State private backupBusy: boolean = false;
  @State private confirmingRestore: boolean = false;
  @State private backupPreview: string = '';
  @State private backupMessage: string = '';
  private selectedBackupText: string = '';

  aboutToAppear(): void {
    this.load();
  }

  build() {
    Column() {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text('设置')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('偏好仅保存在当前设备，不包含物品数据。')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Button('返回')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.back())
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取设置…' })
      } else {
        Scroll() {
          Row() {
            Column({ space: $r('app.float.space_4') }) {
              this.reminderCard()
              this.sortCard()
              this.homeCard()
              this.themeCard()
              this.managementCard()
              this.backupCard()
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_danger'))
                  .padding($r('app.float.space_3'))
                  .borderRadius($r('app.float.radius_control'))
                  .backgroundColor($r('app.color.status_danger_soft'))
              }
              Button(this.saving ? '正在保存…' : '保存设置')
                .width('100%')
                .fontColor($r('app.color.brand_on_primary'))
                .backgroundColor($r('app.color.brand_primary'))
                .borderRadius($r('app.float.radius_control'))
                .enabled(!this.saving)
                .onClick(() => this.save())
            }
            .width('100%')
            .constraintSize({ maxWidth: 880 })
            .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
      }

      MainEntryBar({ activeRoute: RouteName.SETTINGS })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private cardTitle(title: string, description: string) {
    Column({ space: $r('app.float.space_1') }) {
      Text(title)
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(description)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
  }

  @Builder
  private reminderCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('提醒', '系统提醒只在保存物品后按项目单独创建。')
      Text('默认提前提醒天数')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.defaultReminderDays, placeholder: '7' })
        .type(InputType.Number)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.defaultReminderDays = value)
      Row() {
        Text('允许创建系统提醒')
          .layoutWeight(1)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
          .onChange((value: boolean) => this.reminderEnabled = value)
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private sortCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('列表排序', '默认排序不影响当前的搜索与筛选条件。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.sortChoiceButton('最近更新', ItemSortMode.UPDATED_DESC)
        this.sortChoiceButton('最近添加', ItemSortMode.CREATED_DESC)
        this.sortChoiceButton('名称 A-Z', ItemSortMode.NAME_ASC)
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private homeCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('首页内容', '关闭分区不会删除任何本地物品。')
      this.switchRow('最近添加', this.showRecentSection, (value: boolean) => this.showRecentSection = value)
      this.switchRow('即将到期', this.showExpirySection, (value: boolean) => this.showExpirySection = value)
      this.switchRow('待补货', this.showStockSection, (value: boolean) => this.showStockSection = value)
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private themeCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('外观', '主题偏好保存后会立即应用到当前界面。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.themeChoiceButton('跟随系统', ThemeMode.SYSTEM)
        this.themeChoiceButton('浅色', ThemeMode.LIGHT)
        this.themeChoiceButton('深色', ThemeMode.DARK)
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private managementCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('数据管理', '维护常用位置和分类，不影响已有物品记录。')
      Row({ space: $r('app.float.space_2') }) {
        Button('位置管理')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LOCATION_MANAGEMENT }))
        Button('分类管理')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.CATEGORY_MANAGEMENT }))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private backupCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('本地备份与恢复', '备份包含物品、批次、位置、分类、借还记录、库存阈值和照片；不包含系统提醒或偏好设置。')
      Button(this.backupBusy ? '正在处理…' : '保存备份文件')
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.backupBusy)
        .onClick(() => this.saveBackupFile())
      Button('选择备份文件并预览')
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.backupBusy)
        .onClick(() => this.selectBackupFile())
      if (this.backupPreview.length > 0) {
        Column({ space: $r('app.float.space_3') }) {
          Text(this.backupPreview)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
          Button('确认覆盖当前数据并恢复')
            .width('100%')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.status_danger'))
            .enabled(!this.backupBusy && !this.confirmingRestore)
            .onClick(() => this.confirmBackupRestore())
        }
        .width('100%')
        .padding($r('app.float.space_3'))
        .borderRadius($r('app.float.radius_control'))
        .backgroundColor($r('app.color.status_warning_soft'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({ duration: this.reduceAnimation ? 0 : 240, curve: Curve.EaseOut }))
      }
      Button('导出最近一次恢复前的安全备份')
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.backupBusy)
        .onClick(() => this.saveSafetyBackupFile())
      if (this.backupMessage.length > 0) {
        Text(this.backupMessage)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  private async saveBackupFile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.backupMessage = '文件选择器暂不可用';
      return;
    }
    this.backupBusy = true;
    try {
      const result = await AppServices.get().portableBackup.saveToUserFile(context);
      this.backupMessage = result.ok ? (result.getData() ? '备份文件已保存' : '已取消保存') : result.getError().message;
    } catch (_) {
      this.backupMessage = '备份失败，请稍后重试';
    } finally {
      this.backupBusy = false;
    }
  }

  private async selectBackupFile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.backupMessage = '文件选择器暂不可用';
      return;
    }
    this.backupBusy = true;
    this.selectedBackupText = '';
    this.backupPreview = '';
    try {
      const selected = await AppServices.get().portableBackup.selectUserFile(context);
      if (!selected.ok) {
        this.backupMessage = selected.getError().message;
      } else if (selected.getData() !== undefined) {
        const text = selected.getData() ?? '';
        const preview = AppServices.get().portableBackup.preview(text);
        if (preview.ok) {
          this.selectedBackupText = text;
          const counts = preview.getData();
          this.backupPreview = `将覆盖当前数据：${counts.itemCount} 个物品、${counts.batchCount} 个批次、${counts.locationCount} 个位置、${counts.categoryCount} 个分类、${counts.traceEventCount} 条借还记录。`;
          this.backupMessage = '请核对预览后再确认恢复。';
        } else {
          this.backupMessage = preview.getError().message;
        }
      }
    } catch (_) {
      this.backupMessage = '读取备份失败，请重试';
    } finally {
      this.backupBusy = false;
    }
  }

  private async confirmBackupRestore(): Promise<void> {
    if (this.confirmingRestore || this.backupBusy || this.selectedBackupText.length === 0) {
      return;
    }
    this.confirmingRestore = true;
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: '确认恢复备份？',
        message: '当前物品和照片将被备份中的内容覆盖。应用会先保存一份恢复前的安全备份。',
        buttons: [{ text: '取消', color: '#777777' }, { text: '确认恢复', color: '#B42318' }]
      });
      if (result.index === 1) {
        await this.restoreSelectedBackup();
      }
    } catch (_) {
      this.backupMessage = '无法打开确认窗口，请稍后重试';
    } finally {
      this.confirmingRestore = false;
    }
  }

  private async restoreSelectedBackup(): Promise<void> {
    if (this.selectedBackupText.length === 0 || this.backupBusy) {
      return;
    }
    this.backupBusy = true;
    try {
      const result = await AppServices.get().portableBackup.restore(this.selectedBackupText, true);
      this.backupMessage = result.ok ? result.getData() : result.getError().message;
    } catch (_) {
      this.backupMessage = '恢复失败，请检查应用内安全备份后重试';
    } finally {
      this.selectedBackupText = '';
      this.backupPreview = '';
      this.backupBusy = false;
    }
  }

  private async saveSafetyBackupFile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.backupMessage = '文件选择器暂不可用';
      return;
    }
    this.backupBusy = true;
    try {
      const result = await AppServices.get().portableBackup.saveSafetyBackup(context);
      this.backupMessage = result.ok ? (result.getData() ? '安全备份已导出' : '已取消保存') : result.getError().message;
    } catch (_) {
      this.backupMessage = '导出安全备份失败，请重试';
    } finally {
      this.backupBusy = false;
    }
  }

  @Builder
  private sortChoiceButton(label: string, mode: ItemSortMode) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontSize($r('app.float.font_caption'))
      .fontColor(this.defaultSort === mode ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
      .backgroundColor(this.defaultSort === mode ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => this.defaultSort = mode)
  }

  @Builder
  private themeChoiceButton(label: string, mode: ThemeMode) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontSize($r('app.float.font_caption'))
      .fontColor(this.themeMode === mode ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
      .backgroundColor(this.themeMode === mode ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => this.themeMode = mode)
  }

  @Builder
  private switchRow(label: string, isOn: boolean, action: (value: boolean) => void) {
    Row() {
      Text(label)
        .layoutWeight(1)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(action)
    }
    .width('100%')
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await AppServices.get().preferences.get();
      if (result.ok) {
        this.applyPreferences(result.getData());
        if (!result.getData().reminderEnabled) {
          const cancelledResult = await AppServices.get().reminders.cancelAllForDisabledPreference();
          if (!cancelledResult.ok) {
            this.errorMessage = `提醒已关闭，但${cancelledResult.getError().message}`;
            this.persistedReminderEnabled = true;
          }
        }
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '读取设置失败，请重试';
    } finally {
      this.loading = false;
    }
  }

  private applyPreferences(preferences: UserPreferences): void {
    this.defaultReminderDays = preferences.defaultReminderDays.toString();
    this.defaultSort = preferences.defaultSort;
    this.showRecentSection = preferences.showRecentSection;
    this.showExpirySection = preferences.showExpirySection;
    this.showStockSection = preferences.showStockSection;
    this.themeMode = preferences.themeMode;
    this.reminderEnabled = preferences.reminderEnabled;
    this.persistedReminderEnabled = preferences.reminderEnabled;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.errorMessage = '';
    const preferences: UserPreferences = {
      defaultReminderDays: Number(this.defaultReminderDays),
      defaultSort: this.defaultSort,
      showRecentSection: this.showRecentSection,
      showExpirySection: this.showExpirySection,
      showStockSection: this.showStockSection,
      themeMode: this.themeMode,
      reminderEnabled: this.reminderEnabled
    };
    const wasReminderEnabled = this.persistedReminderEnabled;
    this.saving = true;
    try {
      const result = await AppServices.get().preferences.save(preferences);
      if (result.ok) {
        this.applyPreferences(result.getData());
        this.applyColorMode(result.getData().themeMode);
        await this.applySystemBarStyle(result.getData().themeMode);
        AppEventBus.notifyPreferencesChanged();
        if (!this.reminderEnabled && wasReminderEnabled) {
          const cancelledResult = await AppServices.get().reminders.cancelAllForDisabledPreference();
          if (!cancelledResult.ok) {
            this.errorMessage = `设置已保存，但${cancelledResult.getError().message}`;
            this.persistedReminderEnabled = true;
            return;
          }
        }
        this.showSavedToast();
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '保存设置失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private applyColorMode(themeMode: ThemeMode): void {
    const colorMode = themeMode === ThemeMode.DARK
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : themeMode === ThemeMode.LIGHT
        ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    try {
      const hostContext = this.getUIContext().getHostContext();
      hostContext?.getApplicationContext().setColorMode(colorMode);
    } catch (_) {
    }
  }

  private async applySystemBarStyle(themeMode: ThemeMode): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        return;
      }
      const useLightIcon = themeMode === ThemeMode.DARK ||
        (themeMode === ThemeMode.SYSTEM &&
          hostContext.resourceManager.getConfigurationSync().colorMode ===
            resourceManager.ColorMode.DARK);
      const contentColor = useLightIcon ? '#FFFFFF' : '#000000';
      const mainWindow = await window.getLastWindow(hostContext);
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
      const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const uiContext = mainWindow.getUIContext();
      AppStorage.setOrCreate<number>('itemtrace.safeAreaTop', Math.max(0, uiContext.px2vp(avoidArea.topRect.height)));
      AppStorage.setOrCreate<number>('itemtrace.safeAreaBottom', Math.max(0, uiContext.px2vp(avoidArea.bottomRect.height)));
    } catch (_) {
    }
  }

  private showSavedToast(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '设置已保存', duration: 1600 });
    } catch (_) {
    }
  }
}
