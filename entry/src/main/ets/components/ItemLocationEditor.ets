import { AppEventBus } from '../common/AppEventBus';
import { Batch } from '../model/Batch';
import { LocationRecord } from '../model/Location';
import { AppServices } from '../service/AppServices';
import { RoundedButtonStyle } from '../ui/VisualStyle';
import { LocationInput } from './LocationInput';
import { LoadingState } from './LoadingState';

/**
 * 详情页和编辑页共用换位置操作，始终修改实际存放的批次。
 */
@Component
export struct ItemLocationEditor {
  @Prop itemId: string = '';
  @Link saving: boolean;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private locationLoadError: string = '';
  @State private itemName: string = '';
  @State private batches: Batch[] = [];
  @State private selectedBatchId: string = '';
  @State private locationPath: string = '';
  @State private locations: LocationRecord[] = [];
  onSaved: (message: string) => void = (_message: string) => {};
  private generation: number = 0;

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          if (this.loading) {
            LoadingState({ text: '正在读取存放位置…' })
          } else {
            Text(this.itemName).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            if (this.batches.length > 1) {
              Text('要移动哪一份？').fontSize(14).fontColor($r('app.color.text_primary'))
              ForEach(this.batches, (batch: Batch) => {
                Button(`${this.selectedBatchId === batch.id ? '✓ ' : ''}${batch.locationPath ?? '未填写位置'} · ${batch.quantity}${batch.unit}${batch.expirationDate === undefined ? '' : ` · ${batch.expirationDate} 到期`}`)
                  .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .width('100%').height('auto').padding(12).enabled(!this.saving)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor(this.selectedBatchId === batch.id ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
                  .onClick(() => this.selectBatch(batch))
              }, (batch: Batch) => batch.id)
            }
            if (this.selectedBatchId.length > 0) {
              Text('现在放在哪里？').fontSize(14).fontColor($r('app.color.text_primary'))
              LocationInput({ locationPath: $locationPath, locations: this.locations, inputEnabled: !this.saving,
                loadError: this.locationLoadError, onRetry: () => this.loadLocations() })
            }
            if (this.batches.length === 0) {
              Text('目前没有可移动的物品，补入物品后再记录位置。')
                .fontSize(14).fontColor($r('app.color.text_secondary'))
              Button('重新读取').enabled(!this.saving).onClick(() => this.load())
            }
          }
        }.width('100%').padding({ left: 24, right: 24, bottom: 16 }).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).width('100%').layoutWeight(1)
      Column({ space: 8 }) {
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage).fontSize(13).fontColor($r('app.color.status_danger')).width('100%')
        }
        Button(this.saving ? '正在保存…' : '确认换位置')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').height(48)
          .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
          .enabled(!this.loading && !this.saving && this.selectedBatchId.length > 0)
          .onClick(() => this.save())
      }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 24 })
        .backgroundColor($r('app.color.surface_card'))
    }.width('100%').height('100%')
  }

  private async load(): Promise<void> {
    const generation = ++this.generation;
    this.loading = true;
    this.errorMessage = '';
    try {
      const item = await AppServices.get().detailItem.getDetail(this.itemId);
      const batches = await AppServices.get().batches.listByItemId(this.itemId);
      if (generation !== this.generation) { return; }
      if (!item.ok) { this.errorMessage = item.getError().message; return; }
      if (!batches.ok) { this.errorMessage = batches.getError().message; return; }
      this.itemName = item.getData().name;
      this.batches = batches.getData().filter((batch: Batch) => batch.quantity > 0);
      if (this.batches.length === 1) { this.selectBatch(this.batches[0]); }
      await this.loadLocations();
    } catch (_) {
      if (generation === this.generation) { this.errorMessage = '读取位置失败，请重试'; }
    } finally {
      if (generation === this.generation) { this.loading = false; }
    }
  }

  private selectBatch(batch: Batch): void {
    this.selectedBatchId = batch.id;
    this.locationPath = batch.locationPath ?? '';
    this.errorMessage = '';
  }

  private async loadLocations(): Promise<void> {
    const generation = this.generation;
    try {
      const result = await AppServices.get().locations.list();
      if (generation !== this.generation) { return; }
      if (result.ok) { this.locations = result.getData(); this.locationLoadError = ''; }
      else { this.locationLoadError = '历史位置暂时无法读取，可以直接输入。'; }
    } catch (_) {
      if (generation === this.generation) { this.locationLoadError = '历史位置暂时无法读取，可以直接输入。'; }
    }
  }

  private async save(): Promise<void> {
    if (this.saving || this.selectedBatchId.length === 0) { return; }
    this.saving = true;
    this.errorMessage = '';
    try {
      const result = await AppServices.get().batches.move(this.selectedBatchId, this.locationPath);
      if (!result.ok) { this.errorMessage = result.getError().message; return; }
      let message = `已移到 ${this.locationPath.trim()}`;
      try {
        const reminder = await AppServices.get().reminders.reconcileLatest(this.itemId);
        if (!reminder.ok) { message += '，到期提醒暂未更新'; }
      } catch (_) { message += '，到期提醒暂未更新'; }
      AppEventBus.notifyDataChanged();
      this.onSaved(message);
    } catch (_) { this.errorMessage = '保存位置失败，请重试'; }
    finally { this.saving = false; }
  }
}
