import { router } from '@kit.ArkUI';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { ErrorState } from '../components/ErrorState';
import { ExpiryStatusTag } from '../components/ExpiryStatusTag';
import { LoadingState } from '../components/LoadingState';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item } from '../model/Item';
import { ItemFormRouteParams, createItemResult, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct ItemDetailPage {
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private item: Item | undefined = undefined;
  @State private expiryStatus: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @State private showDeleteConfirm: boolean = false;
  @State @Watch('handleDeleteRequest') private deleteRequested: boolean = false;
  private itemId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as ItemFormRouteParams;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loading = false;
      this.errorMessage = itemIdResult.getError().message;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.loadDetail();
  }

  onPageShow(): void {
    if (this.itemId.length > 0) {
      this.loadDetail();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('物品详情')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          if (this.item !== undefined) {
            Button('编辑')
              .onClick(() => this.openEdit())
            Button('删除')
              .margin({ left: 8 })
              .backgroundColor('#B42318')
              .onClick(() => this.showDeleteConfirm = true)
          }
        }
        .width('100%')
        .padding(16)

        if (this.loading) {
          LoadingState({ text: '正在读取物品详情…' })
        } else if (this.errorMessage.length > 0) {
          ErrorState({ message: this.errorMessage })
          Button('返回列表')
            .onClick(() => router.back())
        } else if (this.item !== undefined) {
          this.detailContent(this.item)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')

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
      Column({ space: 16 }) {
        Row() {
          Text(item.name)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          ExpiryStatusTag({ status: this.expiryStatus })
        }
        this.detailRow('数量', `${item.quantity}${item.unit}`)
        this.detailRow('位置', item.locationPath ?? '未设置')
        this.detailRow('分类', item.category ?? '未设置')
        this.detailRow('到期日期', item.expirationDate ?? '未设置')
        this.detailRow('提前提醒天数', item.reminderDays === undefined ? '默认 7 天' : `${item.reminderDays} 天`)
        Column({ space: 6 }) {
          Text('注意事项')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text(item.notes ?? '未填写')
            .fontSize(15)
            .width('100%')
        }
        Column({ space: 6 }) {
          Text('物品照片')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text('暂未添加照片，照片功能将在后续阶段提供。')
            .fontSize(15)
            .fontColor('#667085')
        }
        if (this.deleting) {
          LoadingState({ text: '正在删除物品…' })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
  }

  @Builder
  private detailRow(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(14)
        .fontColor('#667085')
      Text(value)
        .fontSize(17)
        .width('100%')
    }
    .width('100%')
  }

  private async loadDetail(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await AppServices.get().detailItem.getDetail(this.itemId);
      if (!result.ok) {
        this.errorMessage = result.getError().message;
        return;
      }
      this.item = result.getData();
      this.expiryStatus = AppServices.get().listItems.toSummary(result.getData()).expiryStatus;
    } catch (_) {
      this.errorMessage = '读取物品失败，请重试';
    } finally {
      this.loading = false;
    }
  }

  private openEdit(): void {
    router.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'edit', itemId: this.itemId } });
  }

  private async deleteItem(): Promise<void> {
    this.deleting = true;
    const result = await AppServices.get().deleteItem.delete(this.itemId, true);
    this.deleting = false;
    if (result.ok) {
      router.back({ url: RouteName.ITEM_LIST, params: createItemResult('deleted', this.itemId) });
      return;
    }
    this.showDeleteConfirm = false;
    this.errorMessage = result.getError().message;
  }

  private handleDeleteRequest(): void {
    if (this.deleteRequested) {
      this.deleteRequested = false;
      this.deleteItem();
    }
  }
}
