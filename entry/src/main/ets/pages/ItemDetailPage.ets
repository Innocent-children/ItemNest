import { notificationManager } from '@kit.NotificationKit';
import { ReminderRecordStatus } from '../model/ReminderRecord';
import { Batch } from '../model/Batch';
import { localImageSource } from '../ui/ImageSource';
import { SharedRouteMotion } from '../ui/SharedRouteMotion';
import { PhotoViewer } from '../components/PhotoViewer';
import { InventoryMetrics } from '../components/InventoryMetrics';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, nativeTitleOptions, nativeSheetOptions } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { ErrorState } from '../components/ErrorState';
import { ExpiryStatusTag } from '../components/ExpiryStatusTag';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item, ItemSummary } from '../model/Item';
import { StockThreshold } from '../model/StockThreshold';
import { buildItemRefreshParams, getUnhandledRouteRefreshAt } from '../navigation/RefreshContract';
import { ItemFormRouteParams, requireItemId, RouteRefreshParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';
import { activeLocationText } from '../service/ItemFlowPresentation';

interface ItemDetailParams {
  item: Item;
}

interface DetailRowParams {
  label: string;
  value: string;
}

interface DetailIdentityParams {
  name: string;
  category: string;
  path: string;
}

interface ManagementEntryParams {
  title: string;
  description: string;
  route: RouteName;
  itemId: string;
}

@Component
export struct ItemDetailPage {
  @State private heroPreview: ItemSummary | undefined = undefined;
  @State private sharedPhotoId: string = '';
  @StorageLink('itemnest.sharedItemExpanded') private sharedItemExpanded: boolean = true;
  @StorageLink('itemnest.sharedPageProgress') private sharedPageProgress: number = 1;
  @StorageLink('itemnest.sharedPageRoute') private sharedPageRoute: string = '';
  @State private showPhotoViewer: boolean = false;
  private pageScroller: Scroller = new Scroller();
  @State private viewportWidth: number = 360;
  @State private showActionSheet: boolean = false;
  @State private actionSheetMode: string = 'consume';
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @StorageLink('itemnest.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemnest.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private actionError: string = '';
  @State private item: Item | undefined = undefined;
  @State private expiryStatus: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @State private reminderMessage: string = '';
  @State private reminderEnabled: boolean = false;
  @State private reminderAction: string = 'settings';
  @State private reminderActionText: string = '设置到期通知';
  @StorageLink('itemnest.preferenceRevision') @Watch('onPreferencesChanged') private preferenceRevision: number = 0;
  @State private reminderRetrying: boolean = false;
  @State private defaultReminderDays: number = 7;
  @State private photoPath: string = '';
  @State private removingPhoto: boolean = false;
  @State private batchCount: number = 0;
  @State private stockBatches: Batch[] = [];
  @State private consumeBatchId: string = '';
  @State private borrowedQuantity: number = 0;
  @State private availableQuantity: number = 0;
  @State private inventoryWarning: string = '';
  @State private managementLoadError: string = '';
  @State private managementReady: boolean = false;
  @State private consumeQuantityText: string = '1';
  @State private consuming: boolean = false;
  @State private deletePreviewLoading: boolean = false;
  @State private deletePreviewDescription: string = '';
  @State private stockThreshold: StockThreshold | undefined = undefined;
  @State private thresholdText: string = '0';
  @State private thresholdEnabled: boolean = false;
  @State private thresholdSaving: boolean = false;
  @State private thresholdLoadError: string = '';
  @State private showDeleteConfirm: boolean = false;
  @State @Watch('handleDeleteRequest') private deleteRequested: boolean = false;
  private itemId: string = '';
  private initialSection: string = '';
  @State private reminderSettingsReady: boolean = false;
  private lastRouteRefreshAt: number = 0;
  private lastHandledDataRevision: number = -1;
  private loadRequestCoordinator: LatestRequestCoordinator = new LatestRequestCoordinator();
  private viewRecorded: boolean = false;

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as ItemFormRouteParams | undefined;
    if (!params) {
      this.loading = false;
      this.errorMessage = '缺少物品标识，无法打开页面';
      return;
    }
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loading = false;
      this.errorMessage = itemIdResult.getError().message;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.initialSection = params.section ?? '';
    this.heroPreview = SharedRouteMotion.preview(this.itemId);
    this.sharedPhotoId = SharedRouteMotion.itemTransitionId(this.itemId);
    this.loadDetailForCurrentRevision(true);
  }

  private onPreferencesChanged(): void {
    if (this.itemId.length > 0) { this.loadDetailForCurrentRevision(false); }
  }

  onPageShow(): void {
    if (this.refreshForRevisionChange(false) || this.handleRouteRefreshParams()) {
      return;
    }
    if (this.itemId.length > 0) {
      this.loadDetailForCurrentRevision(false);
    }
  }

  aboutToDisappear(): void {
    SharedRouteMotion.release(RouteName.ITEM_DETAIL, this.itemId);
  }

  private onDataRevisionChanged(): void {
    if (this.itemId.length > 0 && !this.deleting) {
      this.refreshForRevisionChange(false);
    }
  }

  private handleRouteRefreshParams(): boolean {
    try {
      const params = NavigationHelper.getParams() as RouteRefreshParams | undefined;
      const refreshAt = getUnhandledRouteRefreshAt(params, this.lastRouteRefreshAt);
      if (refreshAt > 0) {
        this.lastRouteRefreshAt = refreshAt;
        this.loadDetailForCurrentRevision(false);
        return true;
      }
    } catch (_) {
    }
    return false;
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    if (dataRevision === this.lastHandledDataRevision) {
      return false;
    }
    this.loadDetailForCurrentRevision(showLoading);
    return true;
  }

  private loadDetailForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadDetail(showLoading);
  }

  build() {
    NavDestination() {
      this.pageContent()
    }
    .title({ builder: this.pageHeader, height: 76 }, nativeTitleOptions(this.reduceAnimation))
    .hideBackButton(true)
    .bindToScrollable([this.pageScroller])
    .backgroundColor($r('app.color.surface_app'))
    .opacity(this.sharedPageRoute === RouteName.ITEM_DETAIL ? this.sharedPageProgress : 1)
    .onBackPressed(() => NavigationHelper.handleBackPressed())
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: '物品档案', showBack: true, actionText: this.item === undefined ? '' : '编辑',
          actionEnabled: !this.deleting && !this.consuming, onAction: () => this.openEdit(),
          onBack: () => { if (!NavigationHelper.handleBackPressed()) { NavigationHelper.back(); } } })
  }

  @Builder
  private pageContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {

        if (this.loading) {
          Column({ space: 20 }) {
            if (this.heroPreview !== undefined) {
              Column() {
                this.detailIdentity({ name: this.heroPreview.name, category: this.heroPreview.category ?? '我的物品',
                  path: this.heroPreview.photoPath ?? '' })
              }.width('100%').padding(24).borderRadius(22).backgroundColor($r('app.color.surface_card'))
            }
            LoadingState({ text: '正在读取物品详情…' })
          }.width('100%').padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter') })
        } else if (this.errorMessage.length > 0) {
          Column({ space: $r('app.float.space_3') }) {
            ErrorState({ message: this.errorMessage })
            Button('返回列表')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => NavigationHelper.back())
          }
          .padding($r('app.float.space_4'))
        } else if (this.item !== undefined) {
          this.detailContent({ item: this.item })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 880 })
      .height('100%')
      .padding({ bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
      .backgroundColor($r('app.color.surface_app'))

      if (this.showPhotoViewer) {
        PhotoViewer({ path: this.photoPath, visible: $showPhotoViewer, transitionId: `photo-viewer:${this.itemId}` })
      }

      DeleteConfirmDialog({
        visible: $showDeleteConfirm,
        confirmed: $deleteRequested,
        title: this.item === undefined ? '确认删除物品？' : `删除“${this.item.name}”？`,
        description: this.deletePreviewDescription,
        confirmText: '删除物品及关联记录'
      })
    }
    .width('100%')
    .height('100%').backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showActionSheet, this.actionSheet(), nativeSheetOptions({
      height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE], dragBar: true, showClose: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
      title: { title: this.actionSheetMode === 'consume' ? '记录这次用量' : '补货提醒' },
      backgroundColor: $r('app.color.surface_app'), preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined,
      onWillDismiss: (action: DismissSheetAction) => {
        if (!this.consuming && !this.thresholdSaving) { action.dismiss(); }
      }
    }, this.reduceAnimation))
  }

  @Builder
  private detailIdentity($$: DetailIdentityParams) {
    Row({ space: 18 }) {
      Stack() {
        if (this.sharedPhotoId.length === 0 || this.sharedItemExpanded) {
          Stack() {
            if ($$.path.length > 0) {
              if (!this.showPhotoViewer) {
                Image(localImageSource($$.path)).width('100%').height('100%').objectFit(ImageFit.Cover)
                  .onError(() => this.photoPath = '')
                  .geometryTransition(this.reduceAnimation ? '' : `photo-viewer:${this.itemId}`)
              }
            } else {
              Image($r('app.media.ui_box')).width('46%').height('46%').objectFit(ImageFit.Contain)
                .fillColor($r('app.color.brand_primary'))
            }
          }.width(84).height(96).borderRadius(18).clip(true)
            .backgroundColor($r('app.color.surface_accent'))
            .geometryTransition(this.reduceAnimation ? '' : this.sharedPhotoId)
        }
      }.width(84).height(96)
        .onAreaChange(() => { if (this.sharedPhotoId.length > 0) { SharedRouteMotion.targetReady(this.itemId); } })
        .onClick(() => { if (this.photoPath.length > 0) {
          this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.42, 0.85), () => this.showPhotoViewer = true);
        } })
        .accessibilityText($$.path.length > 0 ? '查看物品照片' : '物品图标')
      Column({ space: 10 }) {
        Text($$.category).fontSize(12).fontColor($r('app.color.text_secondary'))
        Text($$.name).fontSize(27).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        ExpiryStatusTag({ status: this.expiryStatus, expirationDate: this.item?.expirationDate ?? '' })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%')
      .gesture(PanGesture({ direction: PanDirection.Right, distance: 16 })
        .onActionStart(() => {
          if (!this.reduceAnimation && !this.deleting && !this.consuming) { SharedRouteMotion.startReturn(this.itemId); }
        })
        .onActionUpdate((event: GestureEvent) => SharedRouteMotion.updateReturn(event.offsetX / this.viewportWidth))
        .onActionEnd((event: GestureEvent) => SharedRouteMotion.endReturn(event.offsetX / this.viewportWidth > 0.3 || event.velocityX > 700))
        .onActionCancel(() => SharedRouteMotion.endReturn(false)))
  }

  @Builder
  private detailContent($$: ItemDetailParams) {
    Scroll(this.pageScroller) {
      Column({ space: $r('app.float.space_4') }) {
        Column({ space: 20 }) {
          this.detailIdentity({ name: $$.item.name, category: $$.item.category ?? '我的物品', path: this.photoPath })
          Divider().color($r('app.color.border_subtle'))
          InventoryMetrics({ total: $$.item.quantity, unit: $$.item.unit,
            available: this.managementReady ? this.availableQuantity : undefined,
            borrowed: this.managementReady ? this.borrowedQuantity : undefined })
          Text('借出的物品也计入拥有总量。').fontSize(11).fontColor($r('app.color.text_secondary'))
          if (this.inventoryWarning.length > 0) {
            Text(this.inventoryWarning).fontSize(13).fontColor($r('app.color.status_danger'))
          }
          if (this.managementLoadError.length > 0) {
            ErrorState({ message: this.managementLoadError })
            Button('重试读取数量').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => this.loadDetailForCurrentRevision(false))
          }
        }.width('100%').padding(24).borderRadius(22).backgroundColor($r('app.color.surface_card'))
          .alignItems(HorizontalAlign.Start)

        if (this.actionError.length > 0) {
          this.actionErrorPanel()
        }

        this.locationSection({ item: $$.item })
        this.managementSection({ item: $$.item })
        Button('分享物品').width('100%').onClick(() => NavigationHelper.pushUrl({ url: RouteName.SHARE_PREVIEW, params: { itemId: $$.item.id } }))
        this.expirySection({ item: $$.item })
        if ($$.item.notes !== undefined || $$.item.barcode !== undefined) {
          this.notesSection({ item: $$.item })
        }
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Image($r('app.media.ui_box')).width(22).height(22).fillColor($r('app.color.brand_primary'))
              .accessibilityLevel('no')
            Column({ space: 5 }) {
              Text('补货提醒').fontSize(15).fontColor($r('app.color.text_primary'))
              Text(this.thresholdLoadError.length > 0 ? '暂时无法读取，点击重试' :
                this.thresholdEnabled ? `总量少于 ${this.thresholdText}${$$.item.unit} 时标记` : '还未启用')
                .fontSize(12).fontColor($r('app.color.text_secondary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Image($r('app.media.ui_chevron')).width(14).height(14)
              .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
          }.width('100%')
        }
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').padding(20).borderRadius(20).backgroundColor($r('app.color.surface_card'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => { this.actionSheetMode = 'stock'; this.showActionSheet = true; })
        if (this.photoPath.length > 0 || $$.item.photoLocalId !== undefined) {
          this.photoSection({ item: $$.item })
        }
        Button(this.deletePreviewLoading ? '正在读取关联记录…' : '删除这件物品')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width('100%').fontSize(13).fontColor($r('app.color.status_danger'))
          .backgroundColor(Color.Transparent)
          .enabled(!this.deletePreviewLoading && !this.deleting && !this.consuming)
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => this.prepareDeletePreview())

        if (this.deleting) {
          LoadingState({ text: '正在删除物品…' })
        }
      }
      .width('100%')
      .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
      .alignItems(HorizontalAlign.Start)
    }.clip(false)
    .layoutWeight(1)
  }

  @Builder
  private actionSheet() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          if (this.actionError.length > 0) { this.actionErrorPanel() }
          if (this.item !== undefined) {
            if (this.actionSheetMode === 'consume') { this.consumptionSection({ item: this.item }) }
            else { this.lowStockSection({ item: this.item }) }
          }
        }.width('100%').padding({ left: 24, right: 24, bottom: 16 })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
      Column() {
        if (this.item !== undefined) {
          Button(this.actionSheetMode === 'consume' ? (this.consuming ? '正在记录…' : '确认用量') :
            (this.thresholdSaving ? '正在保存…' : '保存补货设置'))
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .width('100%').height(48).fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .enabled(!this.consuming && !this.deleting && !this.thresholdSaving &&
              (this.actionSheetMode !== 'consume' || (this.managementReady && this.availableQuantity > 0)))
            .onClick(() => {
              if (this.actionSheetMode === 'consume') { this.consume(); }
              else if (this.item !== undefined) { this.saveLowStockThreshold(this.item); }
            })
        }
      }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 24 })
        .backgroundColor($r('app.color.surface_card'))
    }.width('100%').height('100%')
  }

  @Builder
  private actionErrorPanel() {
    Row({ space: $r('app.float.space_3') }) {
      Text(this.actionError)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.status_danger'))
        .layoutWeight(1)
      Button('关闭')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .fontColor($r('app.color.status_danger'))
        .backgroundColor($r('app.color.status_danger_soft'))
        .borderRadius($r('app.float.radius_control'))
        .onClick(() => this.actionError = '')
    }
    .width('100%')
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($r('app.color.status_danger_soft'))
  }

  @Builder
  private lowStockSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text('什么时候需要补货？')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('少于下方数量时，在首页加入补货清单。这里只在应用内提示，不发送系统通知。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      if (this.thresholdLoadError.length > 0) {
        Text(this.thresholdLoadError)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.status_danger'))
          .width('100%')
        Button('重新读取补货设置')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .width('100%')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => this.loadDetailForCurrentRevision(false))
      } else {
        Text(`少于多少（${$$.item.unit}）`)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        TextInput({ text: this.thresholdText, placeholder: '例如：2' })
          .borderWidth(1)
          .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'thresholdText'))
          .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
            if (this.focusedField === 'thresholdText') { this.focusedField = ''; }
          }))
          .type(InputType.NUMBER_DECIMAL)
          .backgroundColor($r('app.color.surface_app'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.thresholdSaving)
          .borderColor(this.focusedField === 'thresholdText' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onChange((value: string) => this.thresholdText = value)
        Row() {
          Text('加入首页补货清单')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.thresholdEnabled })
            .enabled(!this.thresholdSaving)
            .onChange((value: boolean) => this.thresholdEnabled = value)
        }
        .width('100%')
        Text(this.lowStockStatusText($$.item))
          .fontSize($r('app.float.font_caption'))
          .fontColor(this.isBelowLowStockThreshold($$.item) ? $r('app.color.status_danger') : $r('app.color.text_secondary'))
          .width('100%')

      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private locationSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text('存放与分类')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.detailRow({ label: '存放位置', value: this.activeLocationText($$.item) })
      if (($$.item.activeLocationPaths?.length ?? 0) === 0 && $$.item.quantity > 0) {
        Button('补充存放位置').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .onClick(() => this.openEdit())
      }
      if (this.batchCount > 1) {
        this.detailRow({ label: '默认位置', value: $$.item.locationPath ?? '未设置' })
        Text('分放在不同地方的物品，可在库存明细中分别调整。')
          .fontSize($r('app.float.font_caption')).fontColor($r('app.color.text_secondary'))
      }
      this.detailRow({ label: '分类', value: $$.item.category ?? '未设置' })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private expirySection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text('到期与提醒')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.detailRow({ label: '到期日期', value: $$.item.expirationDate ?? '未设置' })
      this.detailRow({ label: '提前提醒', value: $$.item.reminderDays === undefined ? `默认提前 ${this.defaultReminderDays} 天` : `提前 ${$$.item.reminderDays} 天` })
      if (this.reminderMessage.length > 0) {
        Text(this.reminderMessage)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      if (this.reminderMessage.length > 0) {
        Button(this.reminderRetrying ? '正在检查…' : this.reminderActionText)
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.reminderRetrying)
          .onClick(() => {
            if (this.reminderAction === 'retry') { this.retryReminder(); }
            else if (this.reminderAction === 'date') { this.openEdit(); }
            else { NavigationHelper.pushUrl({ url: RouteName.SETTINGS, params: { section: 'reminders' } }); }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private notesSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text('注意事项')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($$.item.notes ?? '未填写')
        .fontSize($r('app.float.font_body'))
        .fontColor($$.item.notes === undefined ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
        .width('100%')
      if ($$.item.barcode !== undefined && $$.item.barcode.length > 0) {
        Text(`条码/二维码：${$$.item.barcode}`)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private photoSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text('物品照片')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      if (this.photoPath.length > 0) {
        Button(this.removingPhoto ? '正在移除照片…' : '移除照片')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.status_danger'))
          .backgroundColor($r('app.color.status_danger_soft'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.removingPhoto)
          .onClick(() => this.removePhoto())
      } else {
        Text($$.item.photoLocalId === undefined ? '暂未添加照片。' : '照片暂时无法读取，可在编辑页重新选择。')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  @Builder
  private detailRow($$: DetailRowParams) {
    Row({ space: $r('app.float.space_3') }) {
      Text($$.label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .width(84)
      Text($$.value)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
  }

  private async loadDetail(showLoading: boolean = true): Promise<void> {
    const requestId = this.loadRequestCoordinator.begin();
    if (showLoading) {
      this.loading = true;
      this.errorMessage = '';
    }
    try {
      const result = await AppServices.get().detailItem.getDetail(this.itemId);
      if (!this.loadRequestCoordinator.isCurrent(requestId)) {
        return;
      }
      if (!result.ok) {
        if (showLoading || this.item === undefined) {
          this.errorMessage = result.getError().message;
        }
        return;
      }
      this.errorMessage = '';
      const item = result.getData();
      this.item = item;
      const preferences = await AppServices.get().preferences.get();
      if (!this.loadRequestCoordinator.isCurrent(requestId)) { return; }
      this.reminderSettingsReady = preferences.ok;
      if (preferences.ok && this.loadRequestCoordinator.isCurrent(requestId)) {
        this.defaultReminderDays = preferences.getData().defaultReminderDays;
        this.reminderEnabled = preferences.getData().reminderEnabled;
      }
      this.recordViewedItemOnce(item);
      this.expiryStatus = AppServices.get().listItems.toSummary(item).expiryStatus;
      await this.loadReminderState(item, requestId);
      if (!this.loadRequestCoordinator.isCurrent(requestId)) {
        return;
      }
      await this.loadPhotoPath(item, requestId);
      if (!this.loadRequestCoordinator.isCurrent(requestId)) {
        return;
      }
      await this.loadManagementState(item, requestId);
      await this.loadLowStockThreshold(item, requestId);
      if (this.loadRequestCoordinator.isCurrent(requestId) && this.initialSection === 'stock') {
        this.initialSection = ''; this.actionSheetMode = 'stock'; this.showActionSheet = true;
      }
    } catch (_) {
      if (this.loadRequestCoordinator.isCurrent(requestId) && (showLoading || this.item === undefined)) {
        this.errorMessage = '读取物品失败，请重试';
      }
    } finally {
      if (this.loadRequestCoordinator.isCurrent(requestId)) {
        this.loading = false;
      }
    }
  }

  private openEdit(): void {
    NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'edit', itemId: this.itemId, returnTo: RouteName.ITEM_DETAIL } });
  }

  private async deleteItem(): Promise<void> {
    if (this.deleting) {
      return;
    }
    this.deleting = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().deleteItem.delete(this.itemId, true);
      if (result.ok) {
        this.showDeleteConfirm = false;
        this.showToast('物品已删除');
        const refreshAt = AppEventBus.notifyDataChanged();
        NavigationHelper.back({
          url: RouteName.ITEM_LIST,
          params: buildItemRefreshParams(refreshAt, this.itemId)
        });
        return;
      }
      this.showDeleteConfirm = false;
      this.actionError = result.getError().message;
    } catch (_) {
      this.showDeleteConfirm = false;
      this.actionError = '删除物品失败，请重试';
    } finally {
      this.deleting = false;
    }
  }

  private async loadReminderState(item: Item, requestId?: number): Promise<void> {
    this.reminderAction = 'settings';
    this.reminderActionText = '管理到期通知';
    if (!this.reminderSettingsReady) { this.reminderMessage = '暂时无法读取通知设置，请打开设置后重试。'; return; }
    if (!this.reminderEnabled) {
      const disabledRecord = await AppServices.get().reminders.getRecord(item.id);
      if (!this.canApplyLoadResult(requestId)) { return; }
      if (!disabledRecord.ok || disabledRecord.getData()?.systemReminderId !== undefined) {
        this.reminderMessage = '到期通知已关闭，但旧通知尚未确认取消，请重试检查。';
        this.reminderAction = 'retry'; this.reminderActionText = '重试取消旧通知';
      } else {
        this.reminderMessage = '到期通知已关闭，当前不会发送通知。';
        this.reminderActionText = '开启到期通知';
      }
      return;
    }
    try {
      const allowed = await notificationManager.isNotificationEnabled();
      if (!this.canApplyLoadResult(requestId)) { return; }
      if (!allowed) {
        this.reminderMessage = '系统通知权限已关闭，授权后才能收到通知。';
        this.reminderActionText = '去授权通知';
        return;
      }
    } catch (_) {
      if (!this.canApplyLoadResult(requestId)) { return; }
      this.reminderMessage = '暂时无法确认通知权限，请检查提醒设置。';
      return;
    }
    if (item.expirationDate === undefined) {
      this.reminderMessage = '还没填写到期日期，当前不会安排到期通知。';
      this.reminderAction = 'date'; this.reminderActionText = '填写到期日期';
      return;
    }
    const result = await AppServices.get().reminders.getRecord(item.id);
    if (!this.canApplyLoadResult(requestId)) { return; }
    const record = result.ok ? result.getData() : undefined;
    this.reminderMessage = result.ok ? AppServices.get().reminders.describeRecord(record) : '提醒状态暂时无法读取，请重试。';
    if (!result.ok || record === undefined || record.status === ReminderRecordStatus.FAILED ||
      record.status === ReminderRecordStatus.DISABLED || record.status === ReminderRecordStatus.CANCELLED) {
      this.reminderAction = 'retry'; this.reminderActionText = '重新检查通知';
    }
  }


  private async retryReminder(): Promise<void> {
    if (this.item === undefined || this.reminderRetrying) {
      return;
    }
    const item = this.item;
    this.reminderRetrying = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().reminders.reconcileLatest(item.id);
      AppEventBus.notifyDataChanged();
      await this.loadReminderState(item);
      if (!result.ok) {
        this.actionError = result.getError().message;
      }
    } catch (_) {
      this.actionError = '重试创建提醒失败，请稍后再试';
    } finally {
      this.reminderRetrying = false;
    }
  }

  private async loadPhotoPath(item: Item, requestId?: number): Promise<void> {
    const result = await AppServices.get().photos.getLocalPath(item);
    if (!this.canApplyLoadResult(requestId)) {
      return;
    }
    if (result.ok) {
      this.photoPath = result.getData() ?? '';
    } else {
      this.photoPath = '';
    }
  }

  @Builder
  private consumptionSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Text($$.item.name)
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      if (this.managementReady) {
        Text(`现在可用 ${this.availableQuantity}${$$.item.unit}`)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        Text(this.consumptionPreview())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (this.inventoryWarning.length > 0) {
        Text(this.inventoryWarning)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.status_danger'))
      }
      if (this.managementLoadError.length > 0) {
        Text(this.managementLoadError)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.status_danger'))
        Button('重试读取数量')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => this.loadDetailForCurrentRevision(false))
      }
      if (this.stockBatches.length > 1) {
        Text('从哪里取用？').fontSize(14).fontColor($r('app.color.text_primary'))
        Select(this.consumptionOptions($$.item))
          .selected(this.consumeBatchId.length === 0 ? 0 : this.stockBatches.findIndex((batch: Batch) => batch.id === this.consumeBatchId) + 1)
          .value(this.consumptionOptions($$.item)[this.consumeBatchId.length === 0 ? 0 : this.stockBatches.findIndex((batch: Batch) => batch.id === this.consumeBatchId) + 1].value)
          .width('100%').font({ size: 14 }).backgroundColor($r('app.color.surface_input')).borderRadius(14)
          .enabled(!this.consuming).onSelect((index: number) => this.consumeBatchId = index === 0 ? '' : this.stockBatches[index - 1].id)
      }
      Text(`这次用掉多少（${$$.item.unit}）`).fontSize(14).fontColor($r('app.color.text_primary'))
      TextInput({ text: this.consumeQuantityText, placeholder: '这次用掉多少，例如：1' })
        .borderWidth(1)
        .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'consumeQuantityText'))
        .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
          if (this.focusedField === 'consumeQuantityText') { this.focusedField = ''; }
        }))
        .type(InputType.NUMBER_DECIMAL)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .enabled(!this.consuming && !this.deleting)
        .borderColor(this.focusedField === 'consumeQuantityText' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onChange((value: string) => this.consumeQuantityText = value)
      Text(this.consumeBatchId.length > 0 ? '仅扣减所选位置的库存，借出部分不能消耗。' : '优先使用最早到期的物品；借出部分不能消耗。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

  }

  private consumptionPreview(): string {
    const quantity = Number(this.consumeQuantityText);
    if (this.consumeQuantityText.trim().length === 0 || !Number.isFinite(quantity) || quantity <= 0 || quantity > this.availableQuantity) {
      return '请输入这次用掉的数量。';
    }
    return `记录后可用 ${Number((this.availableQuantity - quantity).toFixed(2))}${this.item?.unit ?? ''}`;
  }

  private activeLocationText(item: Item): string {
    return activeLocationText(item.activeLocationPaths, item.locationPath, item.quantity);
  }

  private consumptionOptions(item: Item): SelectOption[] {
    const options: SelectOption[] = [{ value: '自动选择 · 优先使用最早到期的物品' }];
    for (const batch of this.stockBatches) {
      options.push({ value: `${batch.locationPath ?? item.locationPath ?? '未设置位置'} · ${batch.quantity}${item.unit} · ${batch.expirationDate ?? '无到期日'}` });
    }
    return options;
  }

  private async consume(): Promise<void> {
    if (this.consuming || this.deleting || !this.managementReady) {
      return;
    }
    const value = this.consumeQuantityText.trim();
    const quantity = Number(value);
    if (value.length === 0 || !Number.isFinite(quantity) || quantity <= 0) {
      this.actionError = '请输入这次用掉的数量，必须大于 0';
      return;
    }
    this.consuming = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().batches.consume(this.itemId, quantity, this.consumeBatchId.length > 0 ? this.consumeBatchId : undefined);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      let notice = '消耗已记录，库存已扣减';
      try {
        const reminderResult = await AppServices.get().reminders.reconcileLatest(this.itemId);
        if (!reminderResult.ok) {
          this.actionError = '消耗已记录，系统提醒更新失败，可在下方重试同步';
          notice += '，提醒更新失败';
        }
      } catch (_) {
        this.actionError = '消耗已记录，系统提醒更新失败，可在下方重试同步';
        notice += '，提醒更新失败';
      }
      this.showActionSheet = false;
      this.consumeQuantityText = '1';
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadDetail(false);
      this.showToast(notice);
    } catch (_) {
      this.actionError = '记录消耗失败，请重试';
    } finally {
      this.consuming = false;
    }
  }

  private async prepareDeletePreview(): Promise<void> {
    if (this.deletePreviewLoading || this.deleting || this.consuming) {
      return;
    }
    this.deletePreviewLoading = true;
    this.actionError = '';
    try {
      const itemResult = await AppServices.get().detailItem.getDetail(this.itemId);
      if (!itemResult.ok) {
        this.actionError = itemResult.getError().message;
        return;
      }
      const batchResult = await AppServices.get().batches.listByItemId(this.itemId);
      const eventsResult = await AppServices.get().lending.getEvents(this.itemId);
      const stateResult = await AppServices.get().lending.getState(this.itemId);
      const reminderResult = await AppServices.get().reminders.getRecord(this.itemId);
      const thresholdResult = await AppServices.get().lowStock.getThreshold(this.itemId);
      if (!batchResult.ok || !eventsResult.ok || !stateResult.ok || !reminderResult.ok || !thresholdResult.ok) {
        this.actionError = '关联记录未能完整读取，暂未删除。请重试读取删除信息。';
        return;
      }
      const item = itemResult.getData();
      const outstanding = stateResult.getData().borrowedQuantity;
      const warning = outstanding > 0 ? `
还有 ${outstanding}${item.unit} 尚未归还，删除后无法再追查这些借还记录。` : '';
      this.item = item;
      this.deletePreviewDescription = `将删除 ${batchResult.getData().length} 个批次、${eventsResult.getData().length} 条使用与借还记录、${item.photoLocalId === undefined ? 0 : 1} 张照片、${reminderResult.getData() === undefined ? 0 : 1} 条提醒记录、${thresholdResult.getData() === undefined ? 0 : 1} 条低库存设置。${warning}
删除后不可恢复；点取消会保留物品及全部记录。`;
      this.showDeleteConfirm = true;
    } catch (_) {
      this.actionError = '读取删除信息失败，物品已保留，请重试';
    } finally {
      this.deletePreviewLoading = false;
    }
  }

  @Builder
  private managementSection($$: ItemDetailParams) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 12 }) {
            Image($r('app.media.ui_minus')).width(22).height(22).fillColor($r('app.color.brand_on_primary'))
            Text('记录用量').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.brand_on_primary'))
          }.width('100%')
        }
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1).padding(18).borderRadius(18).backgroundColor($r('app.color.brand_primary'))
          .enabled(this.managementReady && this.availableQuantity > 0 && !this.consuming && !this.deleting)
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => { this.actionError = ''; this.actionSheetMode = 'consume'; this.showActionSheet = true; })
        this.managementEntry({ title: '补入物品', description: '记录这次补入的数量',
          route: RouteName.BATCH_FORM, itemId: $$.item.id })
        this.managementEntry({ title: '借出归还', description: '查看借还记录', route: RouteName.LENDING, itemId: $$.item.id })
      }.width('100%')
      Button(`库存明细 · ${this.batchCount} 个批次`).attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .width('100%').fontSize(13).backgroundColor($r('app.color.surface_card')).fontColor($r('app.color.brand_primary'))
        .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_LIST, params: { itemId: $$.item.id } }))
    }.width('100%')
  }


  @Builder
  private managementEntry($$: ManagementEntryParams) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 12 }) {
        Image($$.route === RouteName.BATCH_FORM ? $r('app.media.ui_box') : $r('app.media.ui_lend'))
          .width(22).height(22).fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
        Text($$.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.brand_primary'))
      }.width('100%')
    }
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1).padding(18).borderRadius(18).backgroundColor($r('app.color.surface_card'))
      .accessibilityText($$.title + '，' + $$.description)
      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
      .onClick(() => NavigationHelper.pushUrl({ url: $$.route, params: { itemId: $$.itemId, mode: $$.route === RouteName.BATCH_FORM ? 'create' : undefined } }))
  }

  private async loadManagementState(item: Item, requestId?: number): Promise<void> {
    if (!this.canApplyLoadResult(requestId)) {
      return;
    }
    this.managementReady = false;
    this.managementLoadError = '';
    try {
      const batchResult = await AppServices.get().batches.listByItemId(item.id);
      if (!this.canApplyLoadResult(requestId)) {
        return;
      }
      if (batchResult.ok) {
        this.batchCount = batchResult.getData().length;
        this.stockBatches = batchResult.getData().filter((batch: Batch) => batch.quantity > 0);
        if (!this.stockBatches.some((batch: Batch) => batch.id === this.consumeBatchId)) { this.consumeBatchId = ''; }
      }
      const lendingResult = await AppServices.get().lending.getState(item.id);
      if (!this.canApplyLoadResult(requestId)) {
        return;
      }
      this.managementReady = batchResult.ok && lendingResult.ok;
      if (lendingResult.ok) {
        const state = lendingResult.getData();
        this.borrowedQuantity = state.borrowedQuantity;
        this.availableQuantity = state.availableQuantity;
        this.inventoryWarning = state.inventoryWarning ?? '';
      }
      this.managementLoadError = !batchResult.ok ? batchResult.getError().message :
        (!lendingResult.ok ? lendingResult.getError().message : '');
    } catch (_) {
      if (this.canApplyLoadResult(requestId)) {
        this.managementLoadError = '读取批次和借还数量失败，请重试';
      }
    }
  }

  private recordViewedItemOnce(item: Item): void {
    if (this.viewRecorded) {
      return;
    }
    this.viewRecorded = true;
    AppServices.get().searchSuggestions.recordViewedItem(item);
  }

  private async loadLowStockThreshold(item: Item, requestId: number): Promise<void> {
    if (!this.loadRequestCoordinator.isCurrent(requestId)) {
      return;
    }
    this.thresholdLoadError = '';
    try {
      const result = await AppServices.get().lowStock.getThreshold(item.id);
      if (!this.loadRequestCoordinator.isCurrent(requestId)) {
        return;
      }
      if (!result.ok) {
        this.thresholdLoadError = result.getError().message;
        return;
      }
      const threshold = result.getData();
      this.stockThreshold = threshold;
      this.thresholdText = threshold === undefined ? '2' : `${threshold.threshold}`;
      this.thresholdEnabled = threshold?.enabled ?? false;
    } catch (_) {
      if (this.loadRequestCoordinator.isCurrent(requestId)) {
        this.thresholdLoadError = '读取补货设置失败，请重试';
      }
    }
  }

  private async saveLowStockThreshold(item: Item): Promise<void> {
    if (this.thresholdSaving) {
      return;
    }
    const value = this.thresholdText.trim();
    if (value.length === 0) {
      this.actionError = '请输入需要补货的最低数量';
      return;
    }
    this.thresholdSaving = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().lowStock.saveThreshold(item.id, Number(value), this.thresholdEnabled);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      const threshold = result.getData();
      this.stockThreshold = threshold;
      this.thresholdText = `${threshold.threshold}`;
      this.thresholdEnabled = threshold.enabled;
      this.thresholdLoadError = '';
      AppEventBus.notifyDataChanged();
      this.showActionSheet = false;
      this.showToast('补货设置已保存');
    } catch (_) {
      this.actionError = '保存补货设置失败，请重试';
    } finally {
      this.thresholdSaving = false;
    }
  }

  private lowStockStatusText(item: Item): string {
    if (this.stockThreshold === undefined) {
      return '还未设置。未开启时，首页仅在物品用完后提示补货。';
    }
    if (!this.stockThreshold.enabled) {
      return `补货数量已保存为 ${this.stockThreshold.threshold}${item.unit}，目前未启用。`;
    }
    if (this.isBelowLowStockThreshold(item)) {
      return `当前总量 ${item.quantity}${item.unit}（包含借出），少于设置的 ${this.stockThreshold.threshold}${item.unit}。`;
    }
    return `当前总量 ${item.quantity}${item.unit}（包含借出），不少于设置的 ${this.stockThreshold.threshold}${item.unit}。`;
  }

  private isBelowLowStockThreshold(item: Item): boolean {
    return this.stockThreshold !== undefined && this.stockThreshold.enabled &&
      item.quantity < this.stockThreshold.threshold;
  }

  private canApplyLoadResult(requestId?: number): boolean {
    return requestId === undefined || this.loadRequestCoordinator.isCurrent(requestId);
  }

  private async removePhoto(): Promise<void> {
    if (this.item === undefined || this.removingPhoto) {
      return;
    }
    const item = this.item;
    this.removingPhoto = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().photos.remove(item);
      if (result.ok) {
        this.item = result.getData();
        this.photoPath = '';
        AppEventBus.notifyDataChanged();
        this.showToast('照片已移除');
      } else {
        this.actionError = result.getError().message;
      }
    } catch (_) {
      this.actionError = '移除照片失败，请重试';
    } finally {
      this.removingPhoto = false;
    }
  }

  private handleDeleteRequest(): void {
    if (this.deleteRequested) {
      this.deleteRequested = false;
      this.deleteItem();
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1600
      });
    } catch (_) {
    }
  }
}
