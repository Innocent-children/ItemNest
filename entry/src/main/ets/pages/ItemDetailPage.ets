import { ItemLocationEditor } from '../components/ItemLocationEditor';
import { QuantityInput } from '../components/QuantityInput';
import { notificationManager } from '@kit.NotificationKit';
import { ReminderRecordStatus } from '../model/ReminderRecord';
import { Batch, ConsumptionReceipt } from '../model/Batch';
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
import { Item, ItemSummary, ItemUnit } from '../model/Item';
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
  @State private locationSaving: boolean = false;
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
  @State private sheetError: string = '';
  @State private item: Item | undefined = undefined;
  @State private expiryStatus: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @State private reminderMessage: string = '';
  @State private reminderOverview: string = '正在检查到期通知…';
  @State private reminderIssue: boolean = false;
  private reminderSectionOffset: number = 0;
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
  @State private allBatches: Batch[] = [];
  @State private selectedStockId: string = '';
  @State private stockQuantityText: string = '';
  @State private actionUnit: ItemUnit = ItemUnit.PIECE;
  @State private operationQuantityError: string = '';
  @State private stockSaving: boolean = false;
  @State private lastConsumption: ConsumptionReceipt | undefined = undefined;
  @State private consumptionMessage: string = '';
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
  private requestedUnit: ItemUnit | undefined = undefined;
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
    this.requestedUnit = params.expectedUnit;
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
          actionEnabled: !this.deleting && !this.consuming && !this.stockSaving, onAction: () => this.openEdit(),
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
      height: SheetSize.LARGE, dragBar: true, showClose: true,
      title: { title: this.actionSheetMode === 'move' ? '换个存放位置' : this.actionSheetMode === 'consume' ? '用掉一些' : this.actionSheetMode === 'adjust' ? '调整数量' : '补货提醒' },
      backgroundColor: $r('app.color.surface_app'), preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined,
      onWillDismiss: (action: DismissSheetAction) => {
        if (!this.consuming && !this.thresholdSaving && !this.stockSaving && !this.locationSaving) { action.dismiss(); }
      }
    }, this.reduceAnimation))
  }

  @Builder
  private locationEditor() {
    ItemLocationEditor({ itemId: this.itemId, saving: $locationSaving, onSaved: (message: string) => {
      this.showActionSheet = false;
      this.showToast(message);
    } })
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
        Text($$.name).fontSize(23).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        if (this.item?.expirationDate !== undefined) {
          ExpiryStatusTag({ status: this.expiryStatus, expirationDate: this.item?.expirationDate ?? '' })
        }
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
          Row({ space: 8 }) {
            Image($r('app.media.ui_location')).width(20).height(20).fillColor($r('app.color.brand_primary'))
            Text(this.activeLocationText($$.item)).fontSize(17).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
          }.width('100%')
          Divider().color($r('app.color.border_subtle'))
          if (this.borrowedQuantity > 0) {
          InventoryMetrics({ total: $$.item.quantity, unit: $$.item.unit,
            available: this.managementReady ? this.availableQuantity : undefined,
            borrowed: this.managementReady ? this.borrowedQuantity : undefined })
          Text('借出的物品也计入拥有总量。').fontSize(11).fontColor($r('app.color.text_secondary'))
          } else {
            Text(this.managementReady ? `可用 ${this.availableQuantity}${$$.item.unit}` : '正在读取数量…')
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          }
          if ($$.item.expirationDate !== undefined) {
            Button(this.reminderOverview + ' · 查看').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .fontSize(13).fontColor(this.reminderIssue ? $r('app.color.status_danger') : $r('app.color.brand_primary'))
              .backgroundColor(this.reminderIssue ? $r('app.color.status_danger_soft') : $r('app.color.surface_accent'))
              .onClick(() => this.pageScroller.scrollTo({ xOffset: 0, yOffset: this.reminderSectionOffset,
                animation: !this.reduceAnimation }))
          }
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
          this.actionErrorPanel(this.actionError, false)
        }

        this.managementSection({ item: $$.item })
        if (this.consumptionMessage.length > 0) {
          Column({ space: 8 }) {
            Text(this.consumptionMessage).fontSize(14).fontColor($r('app.color.text_primary')).width('100%')
            if (this.lastConsumption !== undefined) {
              Button(this.consuming ? '正在撤销…' : '撤销这次消耗').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .enabled(!this.consuming && !this.stockSaving && !this.deleting).onClick(() => this.undoConsumption())
            }
          }.width('100%').padding(16).borderRadius(16).backgroundColor($r('app.color.surface_accent'))
        }
        Button('使用记录').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%')
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_HISTORY, params: { itemId: $$.item.id } }))
        if ($$.item.expirationDate !== undefined || this.reminderIssue) {
          this.expirySection({ item: $$.item })
        } else {
          Button('设置到期日期与提醒').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%')
            .fontSize(14).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
            .onClick(() => this.openExpiryEditor())
        }
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
          .onClick(() => this.openStockThreshold())
        Button('分享物品').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%')
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SHARE_PREVIEW, params: { itemId: $$.item.id } }))
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
    if (this.actionSheetMode === 'move') {
      this.locationEditor()
    } else {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            if (this.sheetError.length > 0) { this.actionErrorPanel(this.sheetError, true) }
            if (this.item !== undefined) {
              if (this.actionSheetMode === 'consume') { this.consumptionSection({ item: this.item }) }
              else if (this.actionSheetMode === 'stock') { this.lowStockSection({ item: this.item }) }
              else { this.stockChangeSection() }
            }
          }.width('100%').padding({ left: 24, right: 24, bottom: 16 })
        }.width('100%').layoutWeight(1).align(Alignment.TopStart)
        Column() {
          if (this.item !== undefined) {
            Button(this.consuming || this.stockSaving || this.thresholdSaving ? '正在保存…' :
              this.actionSheetMode === 'consume' ? '确认用量' :
              this.actionSheetMode === 'adjust' ? '保存数量' : '保存补货设置')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .width('100%').height(48).fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .enabled(!this.consuming && !this.deleting && !this.thresholdSaving && !this.stockSaving &&
                (this.actionSheetMode !== 'consume' || (this.managementReady && this.availableQuantity > 0)))
              .onClick(() => {
                if (this.actionSheetMode === 'consume') { this.consume(); }
                else if (this.actionSheetMode === 'stock' && this.item !== undefined) { this.saveLowStockThreshold(this.item); }
                else { this.saveStockChange(); }
              })
          }
        }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 24 })
          .backgroundColor($r('app.color.surface_card'))
      }.width('100%').height('100%')
    }
  }

  @Builder
  private actionErrorPanel(message: string, inSheet: boolean) {
    Row({ space: $r('app.float.space_3') }) {
      Text(message)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.status_danger'))
        .layoutWeight(1)
      Button('关闭')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .fontColor($r('app.color.status_danger'))
        .backgroundColor($r('app.color.status_danger_soft'))
        .borderRadius($r('app.float.radius_control'))
        .onClick(() => { if (inSheet) { this.sheetError = ''; } else { this.actionError = ''; } })
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
          .fontColor(this.reminderIssue ? $r('app.color.status_danger') : $r('app.color.text_secondary'))
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
            else if (this.reminderAction === 'date') { this.openExpiryEditor(); }
            else { NavigationHelper.pushUrl({ url: RouteName.SETTINGS, params: { section: 'reminders' } }); }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .onAreaChange((_old: Area, area: Area) => this.reminderSectionOffset = Number(area.position.y))

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
      if (this.loadRequestCoordinator.isCurrent(requestId) && this.initialSection.length > 0) {
        const section = this.initialSection;
        this.initialSection = '';
        if (section === 'stock') { this.openStockThreshold(); }
        else if (section === 'consume-one' && this.managementReady && this.allBatches.length === 1) {
          this.openStockAction('consume', false);
          this.actionUnit = this.requestedUnit ?? this.actionUnit;
          await this.consume();
        } else if (['consume', 'consume-one', 'move', 'adjust'].includes(section)) {
          this.openStockAction(section === 'consume-one' ? 'consume' : section);
        }
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

  private openExpiryEditor(): void {
    const batch = this.allBatches.length === 1 ? this.allBatches[0] : undefined;
    NavigationHelper.pushUrl({ url: batch === undefined ? RouteName.BATCH_LIST : RouteName.BATCH_FORM,
      params: { itemId: this.itemId, batchId: batch?.id, mode: batch === undefined ? undefined : 'edit' } });
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
    this.reminderIssue = false;
    if (!this.reminderSettingsReady) {
      this.reminderIssue = true; this.reminderOverview = '通知状态读取失败';
      this.reminderMessage = '暂时无法读取通知设置，请打开设置后重试。'; return;
    }
    if (!this.reminderEnabled) {
      this.reminderOverview = '到期通知已关闭';
      const disabledRecord = await AppServices.get().reminders.getRecord(item.id);
      if (!this.canApplyLoadResult(requestId)) { return; }
      if (!disabledRecord.ok || disabledRecord.getData()?.systemReminderId !== undefined) {
        this.reminderIssue = true; this.reminderOverview = '旧通知尚未取消';
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
        this.reminderIssue = true; this.reminderOverview = '到期通知未获授权';
        this.reminderMessage = '系统通知权限已关闭，授权后才能收到通知。';
        this.reminderActionText = '去授权通知';
        return;
      }
    } catch (_) {
      if (!this.canApplyLoadResult(requestId)) { return; }
      this.reminderIssue = true; this.reminderOverview = '通知状态读取失败';
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
    this.reminderIssue = !result.ok || record === undefined || record.status === ReminderRecordStatus.FAILED ||
      record.status === ReminderRecordStatus.DISABLED || record.status === ReminderRecordStatus.CANCELLED;
    this.reminderOverview = this.reminderIssue ? (record?.systemReminderId === undefined ? '到期通知未安排' : '到期通知待检查') : record?.status === ReminderRecordStatus.SCHEDULED ?
      '到期通知已安排' : record?.status === ReminderRecordStatus.DUE ? '已到提醒时间' : '当前无需到期通知';
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
    try {
      const result = await AppServices.get().reminders.reconcileLatest(item.id);
      AppEventBus.notifyDataChanged();
      await this.loadReminderState(item);
      if (!result.ok) {
        this.reminderMessage = '提醒未同步：' + result.getError().message;
      }
    } catch (_) {
      this.reminderMessage = '重试创建提醒失败，请稍后再试';
      this.reminderIssue = true; this.reminderOverview = '到期通知待检查';
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
      QuantityInput({ quantityText: $consumeQuantityText, unit: $actionUnit, errorMessage: $operationQuantityError,
        title: '这次用掉多少？', description: '', unitEditable: false, inputEnabled: !this.consuming && !this.deleting })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach([1, 2, 5], (quantity: number) => {
          Button(`用掉 ${quantity}${$$.item.unit}`).attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .margin({ right: 8, bottom: 8 }).enabled(!this.consuming && quantity <= this.availableQuantity)
            .onClick(() => { this.consumeQuantityText = quantity.toString(); this.operationQuantityError = ''; })
        })
      }
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
    if (this.consumeQuantityText.trim().length === 0 || !Number.isFinite(quantity) || quantity <= 0) {
      return '请输入这次用掉的数量。';
    }
    if (quantity > this.availableQuantity) { return `目前只有 ${this.availableQuantity}${this.item?.unit ?? ''} 可用，请调整本次用量。`; }
    return `记录后可用 ${Number((this.availableQuantity - quantity).toFixed(2))}${this.item?.unit ?? ''}`;
  }

  private activeLocationText(item: Item): string {
    return activeLocationText(item.activeLocationPaths, item.locationPath, item.quantity, item.borrowedQuantity ?? 0);
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
      this.sheetError = '请输入这次用掉的数量，必须大于 0';
      return;
    }
    if (quantity > this.availableQuantity) {
      this.sheetError = `目前只有 ${this.availableQuantity}${this.item?.unit ?? ''} 可用，请调整本次用量。`;
      return;
    }
    this.consuming = true;
    this.sheetError = '';
    try {
      const result = await AppServices.get().batches.consumeRecorded(this.itemId, quantity, this.consumeBatchId.length > 0 ? this.consumeBatchId : undefined, this.actionUnit);
      if (!result.ok) {
        this.sheetError = result.getError().message;
        return;
      }
      this.lastConsumption = result.getData();
      const receipt = result.getData();
      this.consumptionMessage = `已用掉 ${receipt.quantity}${receipt.unit}，在手从 ${receipt.availableBefore} 变为 ${receipt.availableAfter}${receipt.unit}。`;
      this.showActionSheet = false;
      this.consumeQuantityText = '1';
      await this.refreshAfterStockChange();
      this.showToast(this.reminderIssue ? '消耗已记录，到期通知状态请查看详情' : '消耗已记录，库存已扣减');
    } catch (_) {
      this.sheetError = '记录消耗失败，请重试';
    } finally {
      this.consuming = false;
    }
  }

  private openStockThreshold(): void {
    this.sheetError = '';
    this.thresholdText = this.stockThreshold === undefined ? '2' : `${this.stockThreshold.threshold}`;
    this.thresholdEnabled = this.stockThreshold?.enabled ?? false;
    this.actionSheetMode = 'stock';
    this.showActionSheet = true;
  }

  private openStockAction(mode: string, showSheet: boolean = true): void {
    if (!this.managementReady || this.item === undefined) { return; }
    if (mode === 'move') { this.actionSheetMode = mode; this.showActionSheet = true; return; }
    this.sheetError = '';
    this.operationQuantityError = '';
    this.actionUnit = this.item.unit;
    this.actionSheetMode = mode;
    const candidates = this.allBatches;
    this.selectedStockId = candidates.length === 1 ? candidates[0].id : '';
    this.selectStock(this.selectedStockId);
    if (mode === 'consume') { this.consumeBatchId = ''; this.consumeQuantityText = '1'; }
    this.showActionSheet = showSheet;
  }

  private selectStock(batchId: string): void {
    this.selectedStockId = batchId;
    const batch = this.allBatches.find((value: Batch) => value.id === batchId);
    this.stockQuantityText = batch?.quantity.toString() ?? '';
    this.operationQuantityError = '';
  }

  @Builder
  private stockChangeSection() {
    Column({ space: 16 }) {
      Text(this.item?.name ?? '').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      if (this.allBatches.length > 1) {
        Text('要修改哪一份？').fontSize(14).fontColor($r('app.color.text_primary'))
        ForEach(this.allBatches, (batch: Batch) => {
          Button(`${this.selectedStockId === batch.id ? '✓ ' : ''}${batch.locationPath ?? this.item?.locationPath ?? '未设置位置'} · 总量 ${batch.quantity}${batch.unit} · ${batch.expirationDate ?? '无到期日'}`)
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').height('auto').padding(12)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor(this.selectedStockId === batch.id ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
            .enabled(!this.stockSaving).onClick(() => this.selectStock(batch.id))
        }, (batch: Batch) => batch.id)
      }
      if (this.selectedStockId.length > 0) {
          QuantityInput({ quantityText: $stockQuantityText, unit: $actionUnit, errorMessage: $operationQuantityError,
            title: '核对后的总量', description: '总量包含借出部分；不能减少到借出未还的数量以下。',
            unitEditable: false, inputEnabled: !this.stockSaving })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private async saveStockChange(): Promise<void> {
    if (this.stockSaving || this.consuming || this.selectedStockId.length === 0) {
      this.sheetError = '请先选择要修改的库存'; return;
    }
    if (this.actionSheetMode === 'adjust' && (this.stockQuantityText.trim().length === 0 || this.operationQuantityError.length > 0)) {
      this.sheetError = this.operationQuantityError || '请填写核对后的数量'; return;
    }
    this.stockSaving = true;
    this.sheetError = '';
    try {
      const result = await AppServices.get().batches.adjustQuantity(this.selectedStockId, Number(this.stockQuantityText), this.actionUnit);
      if (!result.ok) { this.sheetError = result.getError().message; return; }
      this.showActionSheet = false;
      this.lastConsumption = undefined;
      this.consumptionMessage = '';
      await this.refreshAfterStockChange();
      this.showToast(`数量已更新为 ${this.stockQuantityText}${this.actionUnit}`);
    } catch (_) { this.sheetError = '保存失败，请重试'; }
    finally { this.stockSaving = false; }
  }

  private async undoConsumption(): Promise<void> {
    const receipt = this.lastConsumption;
    if (receipt === undefined || this.consuming) { return; }
    this.consuming = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().batches.undoConsumption(receipt);
      if (!result.ok) { this.actionError = result.getError().message; return; }
      this.lastConsumption = undefined;
      this.consumptionMessage = `已撤销这次消耗，恢复 ${receipt.quantity}${receipt.unit}。`;
      await this.refreshAfterStockChange();
    } catch (_) { this.actionError = '撤销失败，请重试'; }
    finally { this.consuming = false; }
  }

  private async refreshAfterStockChange(): Promise<void> {
    this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
    let reminderError = '';
    try {
      const reminder = await AppServices.get().reminders.reconcileLatest(this.itemId);
      if (!reminder.ok) { reminderError = reminder.getError().message; }
    } catch (_) { reminderError = '提醒更新失败，请重新检查。'; }
    await this.loadDetail(false);
    if (reminderError.length > 0) {
      if (!this.reminderIssue) { this.reminderOverview = '到期通知待检查'; }
      this.reminderIssue = true;
      this.reminderMessage = '提醒未同步：' + reminderError;
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
        Button('换位置').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1).height(52)
          .fontSize(14).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .enabled(this.managementReady && this.stockBatches.length > 0 && !this.consuming && !this.stockSaving && !this.deleting)
          .onClick(() => this.openStockAction('move'))
        Button('用掉一些').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1).height(52)
          .fontSize(14).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .enabled(this.managementReady && this.availableQuantity > 0 && !this.consuming && !this.deleting && !this.stockSaving)
          .onClick(() => this.openStockAction('consume'))
        Button('借给别人').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1).height(52)
          .fontSize(14).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .enabled(this.managementReady && this.availableQuantity > 0 && !this.consuming && !this.stockSaving && !this.deleting)
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LENDING, params: { itemId: $$.item.id, section: 'borrow' } }))
      }.width('100%')
      if (this.borrowedQuantity > 0) {
        Button(`收回物品 · ${this.borrowedQuantity}${$$.item.unit} 未归还`)
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%')
          .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LENDING, params: { itemId: $$.item.id, section: 'return' } }))
      }
      Row({ space: 10 }) {
        Button('补入物品').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1)
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM, params: { itemId: $$.item.id, mode: 'create' } }))
        Button('调整数量').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1)
          .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
          .enabled(this.managementReady && this.allBatches.length > 0 && !this.consuming && !this.stockSaving && !this.deleting)
          .onClick(() => this.openStockAction('adjust'))
      }.width('100%')
      Button(`存放与到期明细 · ${this.batchCount} 份`).attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .width('100%').fontSize(13).backgroundColor($r('app.color.surface_card')).fontColor($r('app.color.brand_primary'))
        .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_LIST, params: { itemId: $$.item.id } }))
    }.width('100%')
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
        this.allBatches = batchResult.getData();
        this.batchCount = this.allBatches.length;
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
      this.sheetError = '请输入需要补货的最低数量';
      return;
    }
    this.thresholdSaving = true;
    this.sheetError = '';
    try {
      const result = await AppServices.get().lowStock.saveThreshold(item.id, Number(value), this.thresholdEnabled);
      if (!result.ok) {
        this.sheetError = result.getError().message;
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
      this.sheetError = '保存补货设置失败，请重试';
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
