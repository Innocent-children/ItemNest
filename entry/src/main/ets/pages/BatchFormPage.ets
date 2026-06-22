import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { Batch, BatchDraft } from '../model/Batch';
import { ITEM_UNIT_OPTIONS, ItemUnit } from '../model/Item';
import { BatchRouteParams, requireBatchId, requireItemId } from '../navigation/RouteContract';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct BatchFormPage {
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private saving: boolean = false;
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

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as BatchRouteParams;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.errorMessage = itemIdResult.getError().message;
      this.loading = false;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.editMode = params.mode === 'edit';
    if (!this.editMode) {
      this.loading = false;
      this.markClean();
      return;
    }
    const batchIdResult = requireBatchId(params);
    if (!batchIdResult.ok) {
      this.errorMessage = batchIdResult.getError().message;
      this.loading = false;
      return;
    }
    this.batchId = batchIdResult.getData();
    this.loadBatch();
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
            TextInput({ text: this.quantityText, placeholder: '数量' })
              .type(InputType.Number)
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.quantityText = value)
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(ITEM_UNIT_OPTIONS, (unit: ItemUnit) => {
                Button(unit)
                  .type(ButtonType.Capsule)
                  .fontColor(this.unit === unit ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                  .backgroundColor(this.unit === unit ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                  .fontSize($r('app.float.font_caption'))
                  .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                  .onClick(() => this.unit = unit)
              }, (unit: ItemUnit) => unit)
            }
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
              .width('100%')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius($r('app.float.radius_control'))
              .enabled(!this.saving)
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
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
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

  private async loadBatch(): Promise<void> {
    const result = await AppServices.get().batches.listByItemId(this.itemId);
    if (result.ok) {
      const batch = this.findBatch(result.getData(), this.batchId);
      if (batch !== undefined) {
        this.quantityText = batch.quantity.toString();
        this.unit = batch.unit;
        this.expirationDate = batch.expirationDate ?? '';
        this.locationPath = batch.locationPath ?? '';
        this.notes = batch.notes ?? '';
        this.markClean();
      } else {
        this.errorMessage = '批次不存在或已删除';
      }
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
  }

  onBackPress(): boolean {
    this.requestClose();
    return true;
  }

  private requestClose(): void {
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
    this.saving = true;
    this.errorMessage = '';
    const draft = this.createDraft();
    const result = this.editMode ? await AppServices.get().batches.update(this.batchId, draft) : await AppServices.get().batches.create(draft);
    if (result.ok) {
      AppEventBus.notifyDataChanged();
      this.showToast(this.editMode ? '批次已更新' : '批次已保存');
      NavigationHelper.back();
    } else {
      this.errorMessage = result.getError().message;
    }
    this.saving = false;
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
