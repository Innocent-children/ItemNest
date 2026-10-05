import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, dockContentInset, uiSpring, nativeTitleOptions, nativeSheetOptions, uiReveal } from '../ui/VisualStyle';
import { notificationManager } from '@kit.NotificationKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { ItemSortMode, ThemeMode, UserPreferences } from '../model/UserPreferences';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';
import { ImportPreview } from '../common/ImportValidation';

@Component
export struct SettingsPage {
  private pageScroller: Scroller = new Scroller();
  @State private viewportWidth: number = 360;
  @State private showReminderSettings: boolean = false;
  @State private savedPreferenceSignature: string = '';
  @State private preferencesReady: boolean = false;
  @Prop isMainTab: boolean = false;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @State private defaultReminderDays: string = '7';
  @State private defaultSort: ItemSortMode = ItemSortMode.UPDATED_DESC;
  @State private showRecentSection: boolean = true;
  @State private showExpirySection: boolean = true;
  @State private showStockSection: boolean = true;
  @State private themeMode: ThemeMode = ThemeMode.SYSTEM;
  @State private reminderEnabled: boolean = false;
  @State private persistedReminderEnabled: boolean = false;
  @State private reminderSyncing: boolean = false;
  @State private reminderMessage: string = '';
  @State private restorePreviewReady: boolean = false;
  @State private notificationStatus: string = '';
  @State private notificationBusy: boolean = false;
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
    this.loadNotificationStatus();
  }

  build() {
    if (this.isMainTab) {
      this.pageContent()
    } else {
      NavDestination() {
        this.pageContent()
      }
      .title({ builder: this.pageHeader, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true)
      .bindToScrollable([this.pageScroller])
      .backgroundColor($r('app.color.surface_app'))
      .onBackPressed(() => NavigationHelper.handleBackPressed())
    }
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: '我的空间', subtitle: '让整理，更合你的习惯。',
        eyebrow: this.isMainTab ? 'MAKE IT YOURS' : '', showBack: !this.isMainTab })
  }

  @Builder
  private pageContent() {
    Column() {

      if (this.loading) {
        LoadingState({ text: '正在读取设置…' })
      } else {
        Scroll(this.pageScroller) {
          Row() {
            Column({ space: $r('app.float.space_4') }) {
              this.themeCard()
              this.managementCard()
              this.reminderEntry()
              this.homeCard()
              this.sortCard()
              this.backupCard()
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_danger'))
                  .padding($r('app.float.space_3'))
                  .borderRadius($r('app.float.radius_control'))
                  .backgroundColor($r('app.color.status_danger_soft'))
              }

            }
            .width('100%')
            .constraintSize({ maxWidth: 880 })
            .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: dockContentInset(this.isMainTab, this.keyboardVisible, this.safeAreaBottom) })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }.clip(false)
        .layoutWeight(1)
      }

      if (!this.loading && (this.hasPreferenceChanges() || this.saving)) {
        Column({ space: 8 }) {
          Text('有未保存的偏好更改').fontSize(12).fontColor($r('app.color.text_secondary'))
          Button(this.saving ? '正在保存…' : '保存偏好')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .width('100%').height(48).fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .enabled(this.preferencesReady && !this.saving && !this.reminderSyncing).animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.save())
        }.width('100%').constraintSize({ maxWidth: 880 })
          .padding({ left: 24, right: 24, top: 12, bottom: dockContentInset(this.isMainTab, this.keyboardVisible, this.safeAreaBottom) })
          .backgroundColor($r('app.color.surface_card'))
          .transition(uiReveal(this.reduceAnimation))
      }
      if (this.loading) {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showReminderSettings, this.reminderSettingsSheet(), nativeSheetOptions({
      height: SheetSize.LARGE, dragBar: true, showClose: true,
      title: { title: '到期提醒', subtitle: '提前一步，减少遗忘' },
      backgroundColor: $r('app.color.surface_app'), preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined
    }, this.reduceAnimation))
  }

  @Builder
  private reminderEntry() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Image($r('app.media.ui_clock')).width(24).height(24)
          .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
        Column({ space: 6 }) {
          Text('到期提醒').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Text(this.reminderEnabled ? `提前 ${this.defaultReminderDays} 天提醒` : '尚未开启系统提醒')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.ui_chevron')).width(14).height(14)
          .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
      }.width('100%')
    }
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').padding(22).borderRadius(20).backgroundColor($r('app.color.surface_card'))
      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
      .onClick(() => this.showReminderSettings = true)
  }

  @Builder
  private reminderSettingsSheet() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          this.reminderCard()
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage).fontSize(13).fontColor($r('app.color.status_danger'))
          }
        }.width('100%').padding(24)
      }.width('100%').layoutWeight(1)
      Row() {
        Button(this.saving ? '正在保存…' : this.hasPreferenceChanges() ? '保存偏好与提醒' : '已保存')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .width('100%').height(48).fontColor($r('app.color.brand_on_primary'))
        .backgroundColor($r('app.color.brand_primary'))
        .enabled(this.hasPreferenceChanges() && this.preferencesReady && !this.saving && !this.reminderSyncing)
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onClick(() => this.save())
      }.width('100%').padding({ left: 24, right: 24, bottom: 24 })
    }.width('100%').height('100%')
  }

  private preferenceSignature(): string {
    return JSON.stringify([this.defaultReminderDays, this.defaultSort, this.showRecentSection,
      this.showExpirySection, this.showStockSection, this.themeMode, this.reminderEnabled]);
  }

  private hasPreferenceChanges(): boolean {
    return this.preferencesReady && this.preferenceSignature() !== this.savedPreferenceSignature;
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
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private reminderCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('提醒偏好', '保存后同步已有物品，已过期或无库存的物品不再创建提醒。')
      Text('默认提前提醒天数')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.defaultReminderDays, placeholder: '7' })
        .borderWidth(1)
        .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'defaultReminderDays'))
        .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
          if (this.focusedField === 'defaultReminderDays') { this.focusedField = ''; }
        }))
        .type(InputType.Number)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .enabled(!this.saving && !this.reminderSyncing)
        .borderColor(this.focusedField === 'defaultReminderDays' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onChange((value: string) => this.defaultReminderDays = value)
      Text('默认天数用于新物品和未单独设置提前天数的物品；已有物品保留各自的提前天数，保存设置后会重新同步提醒。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      Row() {
        Text('允许创建系统提醒')
          .layoutWeight(1)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
          .enabled(!this.saving && !this.reminderSyncing)
          .onChange((value: boolean) => this.reminderEnabled = value)
      }
      .width('100%')
      Text(this.notificationStatus)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      Button(this.notificationBusy ? '正在打开…' : '管理系统通知授权')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.notificationBusy && !this.saving && !this.reminderSyncing)
        .onClick(() => this.manageNotificationPermission())
      Button(this.reminderSyncing ? '正在同步提醒…' : '重新同步已有物品的提醒')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.reminderSyncing && !this.saving && !this.notificationBusy)
        .onClick(() => this.synchronizeReminders())
      Text('重新同步使用已保存的设置；修改上方选项后请先保存设置。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      if (this.reminderMessage.length > 0) {
        Text(this.reminderMessage)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  private async loadNotificationStatus(): Promise<void> {
    try {
      this.notificationStatus = await notificationManager.isNotificationEnabled()
        ? '系统通知已授权，保存设置或重新同步即可处理已有物品。'
        : '系统通知尚未授权；到期提醒需要系统通知授权。';
    } catch (_) {
      this.notificationStatus = '暂时无法读取系统通知授权状态。';
    }
  }

  private async manageNotificationPermission(): Promise<void> {
    if (this.notificationBusy) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      this.notificationStatus = '通知授权设置暂不可用，请稍后重试。';
      return;
    }
    this.notificationBusy = true;
    try {
      await notificationManager.openNotificationSettingsWithResult(context);
      await this.loadNotificationStatus();
      if (this.persistedReminderEnabled) {
        await this.synchronizeReminders();
      }
    } catch (_) {
      await this.loadNotificationStatus();
    } finally {
      this.notificationBusy = false;
    }
  }

  @Builder
  private sortCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('默认排序', '也可以在物品列表中临时调整。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.sortChoiceButton('最近更新', ItemSortMode.UPDATED_DESC)
        this.sortChoiceButton('最近添加', ItemSortMode.CREATED_DESC)
        this.sortChoiceButton('名称 A-Z', ItemSortMode.NAME_ASC)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private homeCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('首页内容', '选择打开应用时想看到的内容。')
      this.switchRow('最近添加', this.showRecentSection, (value: boolean) => this.showRecentSection = value)
      this.switchRow('到期待处理', this.showExpirySection, (value: boolean) => this.showExpirySection = value)
      this.switchRow('待补货', this.showStockSection, (value: boolean) => this.showStockSection = value)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private themeCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('外观', '选择让你舒服的明暗。保存后生效。')
      Flex({ wrap: FlexWrap.Wrap }) {
        this.themeChoiceButton('跟随系统', ThemeMode.SYSTEM)
        this.themeChoiceButton('浅色', ThemeMode.LIGHT)
        this.themeChoiceButton('深色', ThemeMode.DARK)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private managementCard() {
    Column({ space: $r('app.float.space_3') }) {
      this.cardTitle('整理方式', '常用位置和分类，由你定义。')
      this.managementRow('存放位置', '房间、柜子、抽屉…', $r('app.media.ui_location'), RouteName.LOCATION_MANAGEMENT)
      Divider().color($r('app.color.border_subtle'))
      this.managementRow('物品分类', '按用途，或按你的习惯', $r('app.media.ui_category'), RouteName.CATEGORY_MANAGEMENT)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private managementRow(title: string, subtitle: string, icon: Resource, route: RouteName) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Image(icon).width(22).height(22).fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
        Column({ space: 5 }) {
          Text(title).fontSize(15).fontColor($r('app.color.text_primary'))
          Text(subtitle).fontSize(12).fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Image($r('app.media.ui_chevron')).width(14).height(14)
          .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
      }.width('100%')
    }
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(Color.Transparent)
      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
      .onClick(() => NavigationHelper.pushUrl({ url: route }))
  }

  @Builder
  private backupCard() {
    Column({ space: $r('app.float.space_3') }) {
      Image($r('app.media.ui_backup')).width(24).height(24).fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
      this.cardTitle('本地备份与恢复', '备份包含物品、批次、位置、分类、借还记录、库存阈值和照片；不包含系统提醒或偏好设置。')
      Button(this.backupBusy ? '正在处理…' : '保存备份文件')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .enabled(!this.backupBusy)
        .onClick(() => this.saveBackupFile())
      Button('选择备份文件并预览')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .width('100%')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.status_danger'))
            .enabled(!this.backupBusy && !this.confirmingRestore && this.restorePreviewReady)
            .onClick(() => this.confirmBackupRestore())
        }
        .width('100%')
        .padding($r('app.float.space_3'))
        .borderRadius($r('app.float.radius_control'))
        .backgroundColor($r('app.color.status_warning_soft'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
      }
      Button('导出最近一次恢复前的安全备份')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
    .alignItems(HorizontalAlign.Start)
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
    this.restorePreviewReady = false;
    try {
      const selected = await AppServices.get().portableBackup.selectUserFile(context);
      if (!selected.ok) {
        this.backupMessage = selected.getError().message;
      } else if (selected.getData() !== undefined) {
        const text = selected.getData() ?? '';
        const preview = AppServices.get().portableBackup.preview(text);
        if (preview.ok) {
          const source = preview.getData();
          this.backupPreview = this.describeBackup(source);
          const current = await AppServices.get().portableBackup.previewCurrent();
          if (current.ok) {
            this.backupPreview += `\n\n当前将被替换的数据：${this.describeCounts(current.getData())}\n` +
              '恢复会用备份整体替换当前物品、批次、位置、分类、借还记录、库存阈值和照片，不会合并；' +
              '偏好设置保留，系统提醒会按当前设置重新检查。';
            this.selectedBackupText = text;
            this.restorePreviewReady = true;
            this.backupMessage = '请核对备份时间、物品示例及被替换的数据后再确认；恢复前会保存安全备份。';
          } else {
            this.backupMessage = `备份可读取，但无法核对当前数据：${current.getError().message}。请重新选择并预览后再恢复。`;
          }
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
    if (this.confirmingRestore || this.backupBusy || this.selectedBackupText.length === 0 || !this.restorePreviewReady) {
      return;
    }
    this.confirmingRestore = true;
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: '确认恢复备份？',
        message: `${this.backupPreview}\n\n应用会先保存一份恢复前的安全备份，再覆盖以上数据。`,
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
    if (this.selectedBackupText.length === 0 || this.backupBusy || !this.restorePreviewReady) {
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
      this.restorePreviewReady = false;
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
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
      .type(ButtonType.Capsule)
      .fontSize($r('app.float.font_caption'))
      .fontColor(this.themeMode === mode ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
      .backgroundColor(this.themeMode === mode ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.9), () => {
        this.themeMode = mode;
      }))
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
          await this.synchronizeReminders();
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
    this.preferencesReady = true;
    this.savedPreferenceSignature = this.preferenceSignature();
  }

  private async save(): Promise<void> {
    if (this.saving || this.reminderSyncing) {
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
    this.saving = true;
    try {
      const result = await AppServices.get().preferences.save(preferences);
      if (result.ok) {
        this.applyPreferences(result.getData());
        this.applyColorMode(result.getData().themeMode);
        await this.applySystemBarStyle(result.getData().themeMode);
        AppEventBus.notifyPreferencesChanged();
        const remindersSucceeded = await this.synchronizeReminders();
        if (remindersSucceeded) {
          this.showSavedToast();
        } else {
          this.errorMessage = '设置已保存；部分提醒未能同步，请查看上方结果并重新同步。';
        }
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '保存设置失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private async synchronizeReminders(): Promise<boolean> {
    if (this.reminderSyncing) {
      return false;
    }
    this.reminderSyncing = true;
    this.reminderMessage = '正在检查已有物品的系统提醒…';
    try {
      const result = await AppServices.get().reminders.reconcileAll();
      if (!result.ok) {
        this.reminderMessage = `提醒同步失败：${result.getError().message}。可重新同步；已保存的设置和物品不会丢失。`;
        return false;
      }
      this.reminderMessage = AppServices.get().reminders.describeSummary(result.getData());
      if (result.getData().failed === 0 && this.errorMessage.startsWith('设置已保存；部分提醒')) {
        this.errorMessage = '';
      }
      return result.getData().failed === 0;
    } catch (_) {
      this.reminderMessage = '提醒同步中断，可重新同步；已保存的设置和物品不会丢失。';
      return false;
    } finally {
      this.reminderSyncing = false;
    }
  }

  private describeBackup(preview: ImportPreview): string {
    const backupTime = preview.exportedAt === undefined ? '未知，请核对物品示例' : this.formatBackupTime(preview.exportedAt);
    const examples = preview.sampleNames.length === 0 ? '（无物品）' : preview.sampleNames.join('、');
    return `备份时间：${backupTime}\n备份内容：${this.describeCounts(preview)}\n物品示例：${examples}`;
  }

  private describeCounts(preview: ImportPreview): string {
    return `${preview.itemCount} 个物品、${preview.batchCount} 个批次、${preview.locationCount} 个位置、` +
      `${preview.categoryCount} 个分类、${preview.traceEventCount} 条借还记录、` +
      `${preview.thresholdCount} 个库存阈值、${preview.photoCount} 张照片。`;
  }

  private formatBackupTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${this.padTime(date.getMonth() + 1)}-${this.padTime(date.getDate())} ` +
      `${this.padTime(date.getHours())}:${this.padTime(date.getMinutes())}:${this.padTime(date.getSeconds())}`;
  }

  private padTime(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
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
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: useLightIcon,
        isNavigationBarLightIcon: useLightIcon,
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
      await mainWindow.setSpecificSystemBarEnabled('navigationIndicator', true);
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
