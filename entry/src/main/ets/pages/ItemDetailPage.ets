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
              .onClick(() => router.back())
          }
          .padding($r('app.float.space_4'))
        } else if (this.item !== undefined) {
          this.detailContent(this.item)
        }
      }
      .width('100%')
      .height('100%')
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
        this.photoSection()

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
  private photoSection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('物品照片')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('暂未添加照片，照片功能将在后续阶段提供。')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
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
