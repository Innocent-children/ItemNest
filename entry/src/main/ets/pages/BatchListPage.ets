import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, nativeTitleOptions } from '../ui/VisualStyle';
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
  private pageScroller: Scroller = new Scroller();
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemnest.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemnest.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @State private loading: boolean = true;
  @State private deleting: boolean = false;
  @State private errorMessage: string = '';
  @State private actionError: string = '';
  @State private clearingLastBatch: boolean = false;
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
    NavDestination() {
      this.pageContent()
    }
    .title({ builder: this.pageHeader, height: 76 }, nativeTitleOptions(this.reduceAnimation))
    .hideBackButton(true)
    .bindToScrollable([this.pageScroller])
    .backgroundColor($r('app.color.surface_app'))
    .onBackPressed(() => NavigationHelper.handleBackPressed())
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: '库存明细', subtitle: '分清位置、数量与到期日期。', showBack: true,
          actionText: '补入物品', actionIcon: $r('app.media.dock_add'),
          onAction: () => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM,
            params: { mode: 'create', itemId: this.itemId } }) })
  }

  @Builder
  private pageContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {

        if (this.actionError.length > 0 || (this.errorMessage.length > 0 && this.batches.length > 0)) {
          Column({ space: $r('app.float.space_2') }) {
            Text(this.actionError.length > 0 ? this.actionError : this.errorMessage)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.status_danger'))
            Text('批次仍在下方，可直接编辑数量或重试刚才的操作。')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
            Button('重新读取批次')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .enabled(!this.deleting)
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => this.loadBatchesForCurrentRevision(false))
          }
          .padding($r('app.float.space_3'))
        }
        if (this.loading) {
          LoadingState({ text: '正在读取批次…' })
        } else if (this.errorMessage.length > 0 && this.batches.length === 0) {
          ErrorState({ message: this.errorMessage })
          Button('重试读取批次')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.loadBatchesForCurrentRevision(true))
        } else if (this.batches.length === 0) {
          EmptyState({ title: '暂无批次', description: '新增批次后，物品总量和最早到期日会自动汇总。' })
          Button('补入物品')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
                    Text(`总量 ${batch.quantity}${batch.unit}`)
                      .fontSize($r('app.float.font_section'))
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Button({ type: ButtonType.Normal }) {
                      Image($r('app.media.ui_more')).width(22).height(22)
                        .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
                    }
                      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width(44).height(44).padding(0).borderRadius(22)
                      .backgroundColor($r('app.color.surface_input')).accessibilityText('批次操作')
                      .enabled(!this.deleting)
                      .bindMenu([
                        { value: '修改数量、位置与到期日', action: () => NavigationHelper.pushUrl({ url: RouteName.BATCH_FORM,
                          params: { mode: 'edit', itemId: this.itemId, batchId: batch.id } }) },
                        { value: this.batches.length === 1 ? '清空数量' : '删除批次', action: () => this.requestDeleteBatch(batch.id) }
                      ])
                      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                  }
                  Text(`到期：${batch.expirationDate ?? '未设置'} · 位置：${batch.locationPath ?? '未设置'}`)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                  if (batch.notes !== undefined) {
                    Text(batch.notes)
                      .fontSize($r('app.float.font_caption'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                }
                .width('100%')
                .padding($r('app.float.space_4'))
                .borderRadius($r('app.float.radius_card'))
                .backgroundColor($r('app.color.surface_card'))

              }
            }, (batch: Batch) => `${batch.id}:${batch.updatedAt}:${batch.quantity}:${batch.expirationDate ?? ''}`)
          }
          .clip(false)
          .layoutWeight(1)
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
        }
      }
      .width('100%')
      .height('100%').constraintSize({ maxWidth: 960 })
      .padding({ bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
      .backgroundColor($r('app.color.surface_app'))

      DeleteConfirmDialog({
        visible: $showDeleteConfirm,
        confirmed: $deleteRequested,
        title: this.clearingLastBatch ? '清空最后一个批次的数量？' : '确认删除批次？',
        description: this.clearingLastBatch ? '数量将改为 0，批次记录保留，之后可重新补入。尚未归还的数量不能清空。' : '此批次将删除，物品数量、位置、到期状态和系统提醒随之更新。尚未归还的数量不能扣除。',
        confirmText: this.clearingLastBatch ? '清空数量' : '删除批次'
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
    this.clearingLastBatch = this.batches.length === 1;
    this.showDeleteConfirm = true;
  }

  private async deleteBatch(batchId: string): Promise<void> {
    if (this.deleting) {
      return;
    }
    this.deleting = true;
    this.actionError = '';
    try {
      const result = await AppServices.get().batches.delete(batchId);
      if (result.ok) {
        let notice = this.clearingLastBatch ? '批次数量已清空，记录已保留' : '批次已删除';
        try {
          const reminderResult = await AppServices.get().reminders.reconcileLatest(this.itemId);
          if (!reminderResult.ok) {
            this.actionError = '库存已更新，系统提醒更新失败，可在物品详情重试';
            notice += '，提醒更新失败';
          }
        } catch (_) {
          this.actionError = '库存已更新，系统提醒更新失败，可在物品详情重试';
          notice += '，提醒更新失败';
        }
        this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
        await this.loadBatches(false);
        this.showToast(notice);
      } else {
        this.actionError = result.getError().message;
      }
    } catch (_) {
      this.actionError = '操作失败，批次已保留，请编辑数量或重试';
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
