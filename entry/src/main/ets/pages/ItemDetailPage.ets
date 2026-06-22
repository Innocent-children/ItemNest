import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { ErrorState } from '../components/ErrorState';
import { ExpiryStatusTag } from '../components/ExpiryStatusTag';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item } from '../model/Item';
import { ReminderRecordStatus } from '../model/ReminderRecord';
import { ItemFormRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct ItemDetailPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private item: Item | undefined = undefined;
  @State private expiryStatus: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @State private reminderMessage: string = '';
  @State private reminderRetrying: boolean = false;
  @State private photoPath: string = '';
  @State private removingPhoto: boolean = false;
  @State private showDeleteConfirm: boolean = false;
  @State @Watch('handleDeleteRequest') private deleteRequested: boolean = false;
  private itemId: string = '';

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
    this.loadDetail(true);
  }

  onPageShow(): void {
    if (this.itemId.length > 0) {
      this.loadDetail(false);
    }
  }

  private onDataRevisionChanged(): void {
    if (this.itemId.length > 0 && !this.deleting) {
      this.loadDetail(false);
    }
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
          this.detailContent(this.item)
        }
      }
      .width('100%')
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
  private detailContent(item: Item) {
    Scroll() {
      Column({ space: $r('app.float.space_4') }) {
        Column({ space: $r('app.float.space_3') }) {
          Row({ space: $r('app.float.space_3') }) {
            Text(item.name.substring(0, 1))
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
              Text(item.name)
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
              Text(`${item.quantity}${item.unit}`)
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

        this.locationSection(item)
        this.expirySection(item)
        this.notesSection(item)
        this.photoSection(item)
        this.managementSection(item)

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
  private locationSection(item: Item) {
    Column({ space: $r('app.float.space_3') }) {
      Text('存放与分类')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.detailRow('位置', item.locationPath ?? '未设置')
      this.detailRow('分类', item.category ?? '未设置')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private expirySection(item: Item) {
    Column({ space: $r('app.float.space_3') }) {
      Text('到期与提醒')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.detailRow('到期日期', item.expirationDate ?? '未设置')
      this.detailRow('提前提醒', item.reminderDays === undefined ? '默认提前 7 天' : `提前 ${item.reminderDays} 天`)
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
  private notesSection(item: Item) {
    Column({ space: $r('app.float.space_3') }) {
      Text('注意事项')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(item.notes ?? '未填写')
        .fontSize($r('app.float.font_body'))
        .fontColor(item.notes === undefined ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
        .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private photoSection(item: Item) {
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
        Text(item.photoLocalId === undefined ? '暂未添加照片。' : '照片暂时无法读取，可在编辑页重新选择。')
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
  private detailRow(label: string, value: string) {
    Row({ space: $r('app.float.space_3') }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .width(84)
      Text(value)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
  }

  private async loadDetail(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
      this.errorMessage = '';
    }
    try {
      const result = await AppServices.get().detailItem.getDetail(this.itemId);
      if (!result.ok) {
        if (showLoading || this.item === undefined) {
          this.errorMessage = result.getError().message;
        }
        return;
      }
      this.errorMessage = '';
      this.item = result.getData();
      this.expiryStatus = AppServices.get().listItems.toSummary(result.getData()).expiryStatus;
      await this.loadReminderState(result.getData());
      await this.loadPhotoPath(result.getData());
    } catch (_) {
      if (showLoading || this.item === undefined) {
        this.errorMessage = '读取物品失败，请重试';
      }
    } finally {
      this.loading = false;
    }
  }

  private openEdit(): void {
    NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'edit', itemId: this.itemId } });
  }

  private async deleteItem(): Promise<void> {
    this.deleting = true;
    const result = await AppServices.get().deleteItem.delete(this.itemId, true);
    if (result.ok) {
      AppEventBus.notifyDataChanged();
      this.showToast('物品已删除');
      NavigationHelper.back();
      return;
    }
    this.deleting = false;
    this.showDeleteConfirm = false;
    this.errorMessage = result.getError().message;
  }

  private async loadReminderState(item: Item): Promise<void> {
    const result = await AppServices.get().reminders.getRecord(item.id);
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
    if (this.item === undefined) {
      return;
    }
    this.reminderRetrying = true;
    const result = await AppServices.get().reminders.reconcile(this.item);
    if (!result.ok) {
      this.reminderMessage = `系统提醒创建失败：${result.getError().message}`;
    } else {
      await this.loadReminderState(this.item);
    }
    this.reminderRetrying = false;
  }

  private async loadPhotoPath(item: Item): Promise<void> {
    const result = await AppServices.get().photos.getLocalPath(item);
    if (result.ok) {
      this.photoPath = result.getData() ?? '';
    } else {
      this.photoPath = '';
    }
  }

  @Builder
  private managementSection(item: Item) {
    Column({ space: $r('app.float.space_3') }) {
      Text('增强管理')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      this.managementEntry(
        '批次管理',
        `当前汇总 ${item.quantity}${item.unit}，可拆分数量、位置和到期日。`,
        '查看批次',
        RouteName.BATCH_LIST,
        item.id
      )
      this.managementEntry(
        '借出与归还',
        '记录借出数量、归还动作和相关说明。',
        '办理借还',
        RouteName.LENDING,
        item.id
      )
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private managementEntry(title: string, description: string, actionText: string, route: RouteName, itemId: string) {
    Row({ space: $r('app.float.space_3') }) {
      Column({ space: $r('app.float.space_1') }) {
        Text(title)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(description)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      Button(actionText)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .borderRadius($r('app.float.radius_control'))
        .onClick(() => NavigationHelper.pushUrl({ url: route, params: { itemId: itemId } }))
    }
    .width('100%')
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($r('app.color.surface_app'))
  }

  private async removePhoto(): Promise<void> {
    if (this.item === undefined) {
      return;
    }
    this.removingPhoto = true;
    const result = await AppServices.get().photos.remove(this.item);
    if (result.ok) {
      this.item = result.getData();
      this.photoPath = '';
      AppEventBus.notifyDataChanged();
      this.showToast('照片已移除');
    } else {
      this.errorMessage = result.getError().message;
    }
    this.removingPhoto = false;
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
