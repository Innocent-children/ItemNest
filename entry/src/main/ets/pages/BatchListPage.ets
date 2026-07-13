import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { Batch } from '../model/Batch';
import { BatchRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Component
export struct BatchListPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private batches: Batch[] = [];
  @State private showDeleteConfirm: boolean = false;
  @State @Watch('handleDeleteRequest') private deleteRequested: boolean = false;
  private itemId: string = '';
  private pendingDeleteBatchId: string = '';
  private lastHandledDataRevision: number = -1;
  private loadRequestCoordinator: LatestRequestCoordinator = new LatestRequestCoordinator();

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as BatchRouteParams | undefined;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loading = false;
      this.errorMessage = itemIdResult.getError().message;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.loadBatchesForCurrentRevision(true);
  }

  onPageShow(): void {
    if (this.itemId.length > 0) {
      this.refreshForRevisionChange(false);
    }
  }

  private onDataRevisionChanged(): void {
    if (this.itemId.length > 0) {
      this.refreshForRevisionChange(false);
    }
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    if (dataRevision === this.lastHandledDataRevision) {
      return false;
    }
    this.loadBatchesForCurrentRevision(showLoading);
    return true;
  }

  private loadBatchesForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadBatches(showLoading);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
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
          Button('新增批次')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius($r('app.float.radius_control'))
            .onClick(() => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM, params: { mode: 'create', itemId: this.itemId } }))
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
                      .onClick(() => this.requestDeleteBatch(batch.id))
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
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
      .backgroundColor($r('app.color.surface_app'))

      DeleteConfirmDialog({
        visible: $showDeleteConfirm,
        confirmed: $deleteRequested,
        title: '确认删除批次？',
        description: '删除后将重新汇总物品数量和最早到期日。',
        confirmText: '删除批次'
      })
    }
    .width('100%')
    .height('100%')
  }

  private async loadBatches(showLoading: boolean = true): Promise<void> {
    const requestId = this.loadRequestCoordinator.begin();
    const itemId = this.itemId;
    if (showLoading) {
      this.loading = true;
      this.errorMessage = '';
    }
    try {
      const result = await AppServices.get().batches.listByItemId(itemId);
      if (!this.loadRequestCoordinator.isCurrent(requestId)) {
        return;
      }
      if (result.ok) {
        this.batches = result.getData();
        this.errorMessage = '';
      } else if (showLoading || this.batches.length === 0) {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      if (this.loadRequestCoordinator.isCurrent(requestId) && (showLoading || this.batches.length === 0)) {
        this.errorMessage = '读取批次失败，请重试';
      }
    } finally {
      if (this.loadRequestCoordinator.isCurrent(requestId)) {
        this.loading = false;
      }
    }
  }

  private requestDeleteBatch(batchId: string): void {
    if (this.deleting) {
      return;
    }
    this.pendingDeleteBatchId = batchId;
    this.showDeleteConfirm = true;
  }

  private async deleteBatch(batchId: string): Promise<void> {
    if (this.deleting) {
      return;
    }
    this.deleting = true;
    try {
      const result = await AppServices.get().batches.delete(batchId);
      if (result.ok) {
        this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
        await this.loadBatches(false);
        this.showToast('批次已删除');
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '删除批次失败，请重试';
    } finally {
      this.pendingDeleteBatchId = '';
      this.deleting = false;
    }
  }

  private handleDeleteRequest(): void {
    if (!this.deleteRequested) {
      return;
    }
    this.deleteRequested = false;
    if (this.pendingDeleteBatchId.length > 0) {
      this.deleteBatch(this.pendingDeleteBatchId);
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
