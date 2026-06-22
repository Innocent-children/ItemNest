import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { ItemSortMode, ThemeMode, UserPreferences } from '../model/UserPreferences';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct SettingsPage {
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
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
          Column({ space: $r('app.float.space_4') }) {
            this.reminderCard()
            this.sortCard()
            this.homeCard()
            this.themeCard()
            this.managementCard()
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
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }
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
    const result = await AppServices.get().preferences.get();
    if (result.ok) {
      this.applyPreferences(result.getData());
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
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
    const result = await AppServices.get().preferences.save(preferences);
    if (result.ok) {
      if (!this.reminderEnabled && wasReminderEnabled) {
        const cancelledResult = await AppServices.get().reminders.cancelAllForDisabledPreference();
        if (!cancelledResult.ok) {
          this.errorMessage = `设置已保存，但${cancelledResult.getError().message}`;
          this.persistedReminderEnabled = true;
          this.saving = false;
          return;
        }
      }
      this.applyPreferences(result.getData());
      this.applyColorMode(result.getData().themeMode);
      await this.applySystemBarStyle(result.getData().themeMode);
      AppEventBus.notifyPreferencesChanged();
      this.showSavedToast();
    } else {
      this.errorMessage = result.getError().message;
    }
    this.saving = false;
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
      const useLightIcon = themeMode === ThemeMode.DARK;
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
