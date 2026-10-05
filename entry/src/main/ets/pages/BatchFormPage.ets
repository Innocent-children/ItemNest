import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { Batch, BatchDraft } from '../model/Batch';
import { ItemUnit } from '../model/Item';
import { buildBatchRefreshParams } from '../navigation/RefreshContract';
import { BatchRouteParams, requireBatchId, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Component
export struct BatchFormPage {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @State private loading: boolean = true;
  @State private formReady: boolean = false;
  @State private saving: boolean = false;
  @State private savePressed: boolean = false;
  @State private errorMessage: string = '';
  @State private quantityText: string = '1';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private expirationDate: string = '';
  @State private locationPath: string = '';
  @State private notes: string = '';
  @State private showDiscardConfirm: boolean = false;
  @State @Watch('handleDiscardRequest') private discardConfirmed: boolean = false;
  private itemId: string = '';
  private batchId: string = '';
  private editMode: boolean = false;
  private initialDraftSignature: string = '';
  private backHandler: () => boolean = () => this.handleNavigationBack();

  aboutToAppear(): void {
    NavigationHelper.registerBackHandler(this.backHandler);
    const params = NavigationHelper.getParams() as BatchRouteParams | undefined;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.errorMessage = itemIdResult.getError().message;
      this.loading = false;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.editMode = params?.mode === 'edit';
    if (this.editMode) {
      const batchIdResult = requireBatchId(params);
      if (!batchIdResult.ok) {
        this.errorMessage = batchIdResult.getError().message;
        this.loading = false;
        return;
      }
      this.batchId = batchIdResult.getData();
    }
    this.loadForm();
  }

  aboutToDisappear(): void {
    NavigationHelper.unregisterBackHandler(this.backHandler);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text(this.editMode ? '编辑批次' : '新增批次')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button('取消')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_control'))
            .enabled(!this.saving)
            .onClick(() => this.requestClose())
        }
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

        if (this.loading) {
          LoadingState({ text: '正在读取批次…' })
        } else {
          Scroll() {
            Column({ space: $r('app.float.space_4') }) {
            Text('填写此批次剩余总量，包含借出部分，不是这次增减的数量。')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
            TextInput({ text: this.quantityText, placeholder: '批次总量' })
              .type(InputType.NUMBER_DECIMAL)
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.quantityText = value)
            Column({ space: $r('app.float.space_1') }) {
              Row() {
                Text('单位')
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.unit)
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('app.color.brand_primary'))
              }
              .width('100%')
              Text('批次单位与物品统一。如需纠正单位，请在编辑物品中修改；数值不会自动换算。')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding($r('app.float.space_3'))
            .backgroundColor($r('app.color.surface_accent'))
            .borderRadius($r('app.float.radius_control'))
            TextInput({ text: this.expirationDate, placeholder: '到期日期 YYYY-MM-DD，可选' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.expirationDate = value)
            TextInput({ text: this.locationPath, placeholder: '批次位置，可选' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.locationPath = value)
            TextArea({ text: this.notes, placeholder: '批次备注，可选' })
              .maxLength(500)
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.notes = value)
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.status_danger'))
            }
            Button(this.saving ? '正在保存…' : '保存批次')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .width('100%')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius($r('app.float.radius_control'))
              .enabled(!this.saving && this.formReady)
              .scale({ x: this.savePressed && !this.reduceAnimation ? 0.96 : 1, y: this.savePressed && !this.reduceAnimation ? 0.96 : 1 })
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.savePressed = true;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.savePressed = false;
                }
              })
              .onClick(() => this.save())
          }
            .width('100%')
            .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
      .backgroundColor($r('app.color.surface_app'))

      DeleteConfirmDialog({
        visible: $showDiscardConfirm,
        confirmed: $discardConfirmed,
        title: '放弃未保存的修改？',
        description: '当前填写的批次内容尚未保存，放弃后无法恢复。',
        confirmText: '放弃编辑'
      })
    }
    .width('100%')
    .height('100%')
  }

  private async loadForm(): Promise<void> {
    try {
      const itemResult = await AppServices.get().detailItem.getDetail(this.itemId);
      if (!itemResult.ok) {
        this.errorMessage = itemResult.getError().message;
        return;
      }
      this.unit = itemResult.getData().unit;
      if (this.editMode) {
        const result = await AppServices.get().batches.listByItemId(this.itemId);
        if (!result.ok) {
          this.errorMessage = result.getError().message;
          return;
        }
        const batch = this.findBatch(result.getData(), this.batchId);
        if (batch === undefined) {
          this.errorMessage = '批次不存在或已删除';
          return;
        }
        this.quantityText = batch.quantity.toString();
        this.expirationDate = batch.expirationDate ?? '';
        this.locationPath = batch.locationPath ?? '';
        this.notes = batch.notes ?? '';
      }
      this.formReady = true;
      this.markClean();
    } catch (_) {
      this.errorMessage = '读取批次信息失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  onBackPress(): boolean {
    return this.handleNavigationBack();
  }

  private handleNavigationBack(): boolean {
    this.requestClose();
    return true;
  }

  private requestClose(): void {
    if (this.saving) {
      return;
    }
    if (this.hasUnsavedChanges()) {
      this.showDiscardConfirm = true;
      return;
    }
    NavigationHelper.back();
  }

  private handleDiscardRequest(): void {
    if (!this.discardConfirmed) {
      return;
    }
    this.discardConfirmed = false;
    NavigationHelper.back();
  }

  private hasUnsavedChanges(): boolean {
    if (this.loading || this.saving) {
      return false;
    }
    return this.currentDraftSignature() !== this.initialDraftSignature;
  }

  private markClean(): void {
    this.initialDraftSignature = this.currentDraftSignature();
  }

  private currentDraftSignature(): string {
    return JSON.stringify({
      quantityText: this.quantityText,
      unit: this.unit,
      expirationDate: this.expirationDate,
      locationPath: this.locationPath,
      notes: this.notes
    });
  }

  private async save(): Promise<void> {
    if (this.saving || !this.formReady) {
      return;
    }
    this.savePressed = false;
    this.saving = true;
    this.errorMessage = '';
    try {
      const draft = this.createDraft();
      const result = this.editMode ? await AppServices.get().batches.update(this.batchId, draft) : await AppServices.get().batches.create(draft);
      if (result.ok) {
        let notice = this.editMode ? '批次已更新' : '批次已保存';
        try {
          const reminderResult = await AppServices.get().reminders.reconcileLatest(this.itemId);
          if (!reminderResult.ok) {
            notice += '，提醒更新失败，可在物品详情重试';
          }
        } catch (_) {
          notice += '，提醒更新失败，可在物品详情重试';
        }
        const refreshAt = AppEventBus.notifyDataChanged();
        this.showToast(notice);
        NavigationHelper.back({
          url: RouteName.BATCH_LIST,
          params: buildBatchRefreshParams(refreshAt, this.itemId, result.getData().id)
        });
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '保存批次失败，请稍后重试';
    } finally {
      this.saving = false;
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

  private createDraft(): BatchDraft {
    return {
      itemId: this.itemId,
      quantity: this.quantityText.trim().length === 0 ? undefined : Number(this.quantityText),
      unit: this.unit,
      expirationDate: this.expirationDate,
      locationPath: this.locationPath,
      notes: this.notes
    };
  }

  private findBatch(batches: Batch[], batchId: string): Batch | undefined {
    for (let index = 0; index < batches.length; index++) {
      if (batches[index].id === batchId) {
        return batches[index];
      }
    }
    return undefined;
  }
}
