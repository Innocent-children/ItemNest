import { RecognitionPanel } from '../components/RecognitionPanel';
import { CaptureDraft } from '../model/SystemFeatures';
import { OptionalDateField } from '../components/OptionalDateField';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, nativeTitleOptions } from '../ui/VisualStyle';
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
import { LocationInput } from '../components/LocationInput';
import { LocationRecord } from '../model/Location';

@Component
export struct BatchFormPage {
  @State private recognitionPhoto: string = '';
  private pageScroller: Scroller = new Scroller();
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @StorageLink('itemnest.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @State private loading: boolean = true;
  @State private formReady: boolean = false;
  @State private saving: boolean = false;
  @State private savePressed: boolean = false;
  @State private errorMessage: string = '';
  @State private quantityText: string = '1';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private expirationDate: string = '';
  @State private locationPath: string = '';
  @State private chooseLocation: boolean = false;
  @State private managedLocations: LocationRecord[] = [];
  @State private locationLoadError: string = '';
  private locationLoadRequestId: number = 0;
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
    this.loadManagedLocations();
  }

  aboutToDisappear(): void {
    NavigationHelper.unregisterBackHandler(this.backHandler);
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
    .systemTransition(NavigationSystemTransitionType.SLIDE_BOTTOM)
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: this.editMode ? '修改库存' : '补入物品', showBack: true,
          subtitle: this.editMode ? '核对数量、位置和到期日。' : '记下这次补入的数量和位置。', actionEnabled: !this.saving,
          onBack: () => this.requestClose() })
  }

  @Builder
  private pageContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {

        if (this.loading) {
          LoadingState({ text: '正在读取批次…' })
        } else {
          Scroll(this.pageScroller) {
            Column({ space: $r('app.float.space_4') }) {
              Text(this.editMode ? '当前数量（包含借出部分）' : '这次补入多少？')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              TextInput({ text: this.quantityText, placeholder: this.editMode ? '当前数量' : '补入数量' })
                .borderWidth(1)
                .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'quantityText'))
                .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
                  if (this.focusedField === 'quantityText') { this.focusedField = ''; }
                }))
                .type(InputType.NUMBER_DECIMAL)
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .borderColor(this.focusedField === 'quantityText' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
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
                Text('与物品使用相同单位，可在编辑物品中统一修改。')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_accent'))
              .borderRadius($r('app.float.radius_control'))
              Button('拍照或选择包装，识别到期日期').enabled(!this.saving).onClick(async () => {
                const result = await AppServices.get().imageSource.captureWithSystemPicker();
                if (result.ok) { this.recognitionPhoto = result.getData() ?? ''; }
                else { this.errorMessage = result.getError().message; }
              })
              if (this.recognitionPhoto.length > 0) {
                RecognitionPanel({ photoUri: this.recognitionPhoto, inputEnabled: !this.saving,
                  onApply: (draft: CaptureDraft) => { if (draft.expirationDate.length > 0) { this.expirationDate = draft.expirationDate; } } })
              }
              Text('到期日期（可选）').fontSize(15).fontColor($r('app.color.text_primary')).width('100%')
              OptionalDateField({ value: $expirationDate, editable: !this.saving })
              Text(this.chooseLocation ? '存放位置（请选择）' : '存放位置（可选）').fontSize(15).fontColor($r('app.color.text_primary')).width('100%')
              LocationInput({ locationPath: $locationPath, locations: this.managedLocations, inputEnabled: !this.saving,
                loadError: this.locationLoadError, onRetry: () => this.loadManagedLocations() })
              Text(this.chooseLocation ? '物品分放在不同位置，请确认这份库存放在哪里。' : '可以选择历史位置，也可以手动填写；留空会沿用已记录的位置。').fontSize(12)
                .fontColor($r('app.color.text_secondary')).width('100%')
              TextArea({ text: this.notes, placeholder: '备注，可选' })
                .borderWidth(1)
                .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'notes'))
                .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
                  if (this.focusedField === 'notes') { this.focusedField = ''; }
                }))
                .maxLength(500)
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .borderColor(this.focusedField === 'notes' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onChange((value: string) => this.notes = value)
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_danger'))
              }

            }
            .width('100%')
            .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
          }.clip(false).align(Alignment.TopStart)
          .layoutWeight(1)
          Column() {
            Button(this.saving ? '正在保存…' : this.editMode ? '保存修改' : '确认补入')
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
          }.width('100%')
            .padding({ left: 20, right: 20, top: 20, bottom: 20 + (this.keyboardVisible ? 0 : this.safeAreaBottom) })
            .backgroundColor($r('app.color.surface_card'))
        }
      }
      .width('100%')
      .height('100%').constraintSize({ maxWidth: 800 })
      .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
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
      const paths = itemResult.getData().activeLocationPaths ?? [];
      this.chooseLocation = paths.length > 1;
      if (!this.editMode) {
        const draft = (NavigationHelper.getParams() as BatchRouteParams | undefined)?.externalRequest;
        this.recognitionPhoto = draft?.photoUri ?? '';
        this.expirationDate = draft?.expirationDate ?? '';
        this.locationPath = draft?.locationPath || (paths.length === 1 ? paths[0] : this.chooseLocation ? '' : itemResult.getData().locationPath ?? '');
      }
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
        this.locationPath = batch.locationPath ?? itemResult.getData().locationPath ?? '';
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

  private async loadManagedLocations(): Promise<void> {
    const requestId = ++this.locationLoadRequestId;
    try {
      const result = await AppServices.get().locations.list();
      if (requestId !== this.locationLoadRequestId) { return; }
      if (result.ok) {
        this.managedLocations = result.getData();
        this.locationLoadError = '';
      } else { this.locationLoadError = '暂时无法读取历史位置，可以继续手动填写。'; }
    } catch (_) {
      if (requestId === this.locationLoadRequestId) {
        this.locationLoadError = '暂时无法读取历史位置，可以继续手动填写。';
      }
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
    if (this.chooseLocation && this.locationPath.trim().length === 0) {
      this.errorMessage = '请先选择或填写这份库存的存放位置';
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
