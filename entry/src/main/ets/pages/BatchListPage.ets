import { NavigationHelper } from '../navigation/NavigationHelper';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { Batch } from '../model/Batch';
import { BatchRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct BatchListPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private batches: Batch[] = [];
  private itemId: string = '';

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as BatchRouteParams;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loading = false;
      this.errorMessage = itemIdResult.getError().message;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.loadBatches();
  }

  onPageShow(): void {
    if (this.itemId.length > 0) {
      this.loadBatches();
    }
  }

  private onDataRevisionChanged(): void {
    if (this.itemId.length > 0) {
      this.loadBatches();
    }
  }

  build() {
    Column() {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text('批次管理')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('按批次记录数量、到期日和位置')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Button('+ 新增')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM, params: { mode: 'create', itemId: this.itemId } }))
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取批次…' })
      } else if (this.errorMessage.length > 0) {
        ErrorState({ message: this.errorMessage })
      } else if (this.batches.length === 0) {
        EmptyState({ title: '暂无批次', description: '新增批次后，物品总量和最早到期日会自动汇总。' })
      } else {
        List({ space: 12 }) {
          ForEach(this.batches, (batch: Batch) => {
            ListItem() {
              Column({ space: $r('app.float.space_2') }) {
                Row() {
                  Text(`${batch.quantity}${batch.unit}`)
                    .fontSize($r('app.float.font_section'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  Button('编辑')
                    .fontColor($r('app.color.brand_primary'))
                    .backgroundColor($r('app.color.surface_accent'))
                    .borderRadius($r('app.float.radius_control'))
                    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM, params: { mode: 'edit', itemId: this.itemId, batchId: batch.id } }))
                  Button(this.deleting ? '删除中…' : '删除')
                    .fontColor($r('app.color.status_danger'))
                    .backgroundColor($r('app.color.status_danger_soft'))
                    .borderRadius($r('app.float.radius_control'))
                    .enabled(!this.deleting)
                    .margin({ left: $r('app.float.space_2') })
                    .onClick(() => this.deleteBatch(batch.id))
                }
                Text(`到期：${batch.expirationDate ?? '未设置'} · 位置：${batch.locationPath ?? '未设置'}`)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_secondary'))
                if (batch.notes !== undefined) {
                  Text(batch.notes)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(2)
                }
              }
              .width('100%')
              .padding($r('app.float.space_4'))
              .borderRadius($r('app.float.radius_card'))
              .backgroundColor($r('app.color.surface_card'))
            }
          }, (batch: Batch) => batch.id)
        }
        .layoutWeight(1)
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }

  private async loadBatches(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result = await AppServices.get().batches.listByItemId(this.itemId);
    if (result.ok) {
      this.batches = result.getData();
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
  }

  private async deleteBatch(batchId: string): Promise<void> {
    this.deleting = true;
    const result = await AppServices.get().batches.delete(batchId);
    if (result.ok) {
      await this.loadBatches();
      AppEventBus.notifyDataChanged();
    } else {
      this.errorMessage = result.getError().message;
    }
    this.deleting = false;
  }
}
