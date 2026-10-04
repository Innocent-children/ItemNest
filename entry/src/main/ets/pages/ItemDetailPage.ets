import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { ErrorState } from '../components/ErrorState';
import { ExpiryStatusTag } from '../components/ExpiryStatusTag';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item } from '../model/Item';
import { ReminderRecordStatus } from '../model/ReminderRecord';
import { StockThreshold } from '../model/StockThreshold';
import { buildItemRefreshParams, getUnhandledRouteRefreshAt } from '../navigation/RefreshContract';
import { ItemFormRouteParams, requireItemId, RouteRefreshParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

interface ItemDetailParams {
  item: Item;
}

interface DetailRowParams {
  label: string;
  value: string;
}

interface ManagementEntryParams {
  title: string;
  description: string;
  route: RouteName;
  itemId: string;
}

@Component
export struct ItemDetailPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private actionError: string = '';
  @State private item: Item | undefined = undefined;
  @State private expiryStatus: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @State private reminderMessage: string = '';
  @State private reminderRetrying: boolean = false;
  @State private defaultReminderDays: number = 7;
  @State private photoPath: string = '';
  @State private removingPhoto: boolean = false;
  @State private batchCount: number = 0;
  @State private borrowedQuantity: number = 0;
  @State private stockThreshold: StockThreshold | undefined = undefined;
  @State private thresholdText: string = '0';
  @State private thresholdEnabled: boolean = false;
  @State private thresholdSaving: boolean = false;
  @State private thresholdLoadError: string = '';
  @State private showDeleteConfirm: boolean = false;
  @State @Watch('handleDeleteRequest') private deleteRequested: boolean = false;
  private itemId: string = '';
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
    this.loadDetailForCurrentRevision(true);
  }

  onPageShow(): void {
    if (this.refreshForRevisionChange(false) || this.handleRouteRefreshParams()) {
      return;
    }
    if (this.itemId.length > 0) {
      this.loadDetailForCurrentRevision(false);
    }
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
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Column({ space: $r('app.float.space_1') }) {
            Text('物品详情')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('查看记录、更新信息或删除物品')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          if (this.item !== undefined) {
            Button('编辑')
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.openEdit())
            Button('删除')
              .margin({ left: $r('app.float.space_2') })
              .fontColor($r('app.color.status_danger'))
              .backgroundColor($r('app.color.status_danger_soft'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.showDeleteConfirm = true)
          }
        }
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

        if (this.loading) {
          LoadingState({ text: '正在读取物品详情…' })
        } else if (this.errorMessage.length > 0) {
          Column({ space: $r('app.float.space_3') }) {
            ErrorState({ message: this.errorMessage })
            Button('返回列表')
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
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
      .backgroundColor($r('app.color.surface_app'))

      DeleteConfirmDialog({
        visible: $showDeleteConfirm,
        confirmed: $deleteRequested
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private detailContent($$: ItemDetailParams) {
    Scroll() {
      Column({ space: $r('app.float.space_4') }) {
        Column({ space: $r('app.float.space_3') }) {
          Row({ space: $r('app.float.space_3') }) {
            Text($$.item.name.substring(0, 1))
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .width(60)
              .height(60)
              .borderRadius(30)
              .textAlign(TextAlign.Center)
              .padding({ top: 12 })
            Column({ space: $r('app.float.space_1') }) {
              Text($$.item.name)
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(`${$$.item.quantity}${$$.item.unit}`)
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.brand_primary'))
            }
            .layoutWeight(1)
          }
          ExpiryStatusTag({ status: this.expiryStatus })
        }
        .width('100%')
        .padding($r('app.float.space_4'))
        .borderRadius($r('app.float.radius_card'))
        .backgroundColor($r('app.color.surface_card'))

        if (this.actionError.length > 0) {
          this.actionErrorPanel()
        }

        this.managementSection({ item: $$.item })
        this.lowStockSection({ item: $$.item })
        this.locationSection({ item: $$.item })
        this.expirySection({ item: $$.item })
        this.notesSection({ item: $$.item })
        this.photoSection({ item: $$.item })

        if (this.deleting) {
          LoadingState({ text: '正在删除物品…' })
        }
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
  }

  @Builder
  private actionErrorPanel() {
    Row({ space: $r('app.float.space_3') }) {
      Text(this.actionError)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.status_danger'))
        .layoutWeight(1)
      Button('关闭')
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
      Text('低库存状态')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('库存低于阈值时，在应用内标记为需要补货。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      if (this.thresholdLoadError.length > 0) {
        Text(this.thresholdLoadError)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.status_danger'))
          .width('100%')
        Button('重试读取阈值')
          .width('100%')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => this.loadDetailForCurrentRevision(false))
      } else {
        Text('提醒阈值')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        TextInput({ text: this.thresholdText, placeholder: '例如：2' })
          .type(InputType.NUMBER_DECIMAL)
          .backgroundColor($r('app.color.surface_app'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.thresholdSaving)
          .onChange((value: string) => this.thresholdText = value)
        Row() {
          Text('启用低库存标记')
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
        Button(this.thresholdSaving ? '正在保存…' : '保存低库存设置')
          .width('100%')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.thresholdSaving)
          .onClick(() => this.saveLowStockThreshold($$.item))
      }
    }
    .width('100%')
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
      this.detailRow({ label: '位置', value: $$.item.locationPath ?? '未设置' })
      this.detailRow({ label: '分类', value: $$.item.category ?? '未设置' })
    }
    .width('100%')
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
      if (this.reminderMessage.includes('失败')) {
        Button(this.reminderRetrying ? '正在重试…' : '重试创建提醒')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.reminderRetrying)
          .onClick(() => this.retryReminder())
      }
    }
    .width('100%')
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
        Image(this.photoPath)
          .width('100%')
          .height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius($r('app.float.radius_control'))
        Button(this.removingPhoto ? '正在移除照片…' : '移除照片')
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
      if (preferences.ok && this.loadRequestCoordinator.isCurrent(requestId)) {
        this.defaultReminderDays = preferences.getData().defaultReminderDays;
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
    const result = await AppServices.get().reminders.getRecord(item.id);
    if (!this.canApplyLoadResult(requestId)) {
      return;
    }
    if (!result.ok) {
      this.reminderMessage = '提醒状态暂时无法读取';
      return;
    }
    const record = result.getData();
    if (record === undefined) {
      this.reminderMessage = '尚未创建系统提醒';
      return;
    }
    if (record.status === ReminderRecordStatus.SCHEDULED) {
      this.reminderMessage = '系统提醒已安排';
      return;
    }
    if (record.status === ReminderRecordStatus.FAILED) {
      this.reminderMessage = `系统提醒创建失败：${record.errorSummary ?? '请检查通知授权后重试'}`;
      return;
    }
    if (record.status === ReminderRecordStatus.NOT_REQUIRED) {
      this.reminderMessage = '当前日期不需要创建系统提醒';
      return;
    }
    this.reminderMessage = '系统提醒已取消';
  }

  private async retryReminder(): Promise<void> {
    if (this.item === undefined || this.reminderRetrying) {
      return;
    }
    const item = this.item;
    this.reminderRetrying = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().reminders.reconcile(item);
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
  private managementSection($$: ItemDetailParams) {
    Column({ space: $r('app.float.space_3') }) {
      Row() {
        Text('管理动作')
          .fontSize($r('app.float.font_section'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('批次 / 借还')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      Row({ space: $r('app.float.space_2') }) {
        this.managementEntry({ title: '批次', description: this.batchCount === 0 ? `汇总 ${$$.item.quantity}${$$.item.unit}` : `${this.batchCount} 个批次`, route: RouteName.BATCH_LIST, itemId: $$.item.id })
        this.managementEntry({ title: '借还', description: this.borrowedQuantity === 0 ? '当前无借出' : `借出 ${this.borrowedQuantity}${$$.item.unit}`, route: RouteName.LENDING, itemId: $$.item.id })
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private managementEntry($$: ManagementEntryParams) {
    Column({ space: $r('app.float.space_1') }) {
      Text($$.title)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text($$.description)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      Text('进入')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.brand_primary'))
    }
    .layoutWeight(1)
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($r('app.color.surface_app'))
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .onClick(() => NavigationHelper.pushUrl({ url: $$.route, params: { itemId: $$.itemId } }))
  }

  private async loadManagementState(item: Item, requestId?: number): Promise<void> {
    const batchResult = await AppServices.get().batches.listByItemId(item.id);
    if (!this.canApplyLoadResult(requestId)) {
      return;
    }
    if (batchResult.ok) {
      this.batchCount = batchResult.getData().length;
    }
    const lendingResult = await AppServices.get().lending.getState(item.id);
    if (!this.canApplyLoadResult(requestId)) {
      return;
    }
    if (lendingResult.ok) {
      this.borrowedQuantity = lendingResult.getData().borrowedQuantity;
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
      this.thresholdText = threshold === undefined ? '0' : `${threshold.threshold}`;
      this.thresholdEnabled = threshold?.enabled ?? false;
    } catch (_) {
      if (this.loadRequestCoordinator.isCurrent(requestId)) {
        this.thresholdLoadError = '读取低库存阈值失败，请重试';
      }
    }
  }

  private async saveLowStockThreshold(item: Item): Promise<void> {
    if (this.thresholdSaving) {
      return;
    }
    const value = this.thresholdText.trim();
    if (value.length === 0) {
      this.actionError = '请输入低库存阈值';
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
      this.showToast('低库存设置已保存');
    } catch (_) {
      this.actionError = '保存低库存设置失败，请重试';
    } finally {
      this.thresholdSaving = false;
    }
  }

  private lowStockStatusText(item: Item): string {
    if (this.stockThreshold === undefined) {
      return '尚未保存低库存阈值。';
    }
    if (!this.stockThreshold.enabled) {
      return `已保存阈值 ${this.stockThreshold.threshold}${item.unit}，提醒当前停用。`;
    }
    if (this.isBelowLowStockThreshold(item)) {
      return `当前库存 ${item.quantity}${item.unit}，低于阈值 ${this.stockThreshold.threshold}${item.unit}。`;
    }
    return `当前库存 ${item.quantity}${item.unit}，未低于阈值 ${this.stockThreshold.threshold}${item.unit}。`;
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
