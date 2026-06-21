import { NavigationHelper } from '../navigation/NavigationHelper';
import { LocationInput } from '../components/LocationInput';
import { LoadingState } from '../components/LoadingState';
import { QuantityInput } from '../components/QuantityInput';
import { CATEGORY_OPTIONS, Category } from '../model/Category';
import { Item, ItemDraft, ItemUnit } from '../model/Item';
import { AssetSource } from '../model/ItemAsset';
import { ItemFormRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppEventBus } from '../common/AppEventBus';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct ItemFormPage {
  @State private name: string = '';
  @State private quantityText: string = '1';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private locationPath: string = '';
  @State private categoryValue: string = '';
  @State private expirationDate: string = '';
  @State private reminderDaysText: string = '';
  @State private notes: string = '';
  @State private scanText: string = '';
  @State private quantityError: string = '';
  @State private errorMessage: string = '';
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private editMode: boolean = false;
  @State private itemId: string = '';
  @State private pendingPhotoUri: string = '';
  @State private pendingPhotoSource: AssetSource = AssetSource.PHOTO_PICKER;
  @State private photoPicking: boolean = false;

  aboutToAppear(): void {
    this.readRoute();
    if (!this.editMode) {
      this.loadDefaultReminderDays();
    }
  }

  build() {
    Column() {
      Column({ space: $r('app.float.space_1') }) {
        Text(this.editMode ? '编辑物品' : '记录新物品')
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.editMode ? '更新后，所有列表和摘要会同步刷新。' : '先记录最重要的信息，其他内容随时补充。')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取物品…' })
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_4') }) {
            Column({ space: $r('app.float.space_4') }) {
              this.fieldTitle('基础信息', '名称必填；数量和单位默认即可保存。')
              TextInput({ text: this.name, placeholder: '例如：感冒药' })
                .maxLength(80)
                .backgroundColor($r('app.color.surface_app'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .onChange((value: string) => this.name = value)
              QuantityInput({ quantityText: $quantityText, unit: $unit, errorMessage: $quantityError })
            }
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))

            Column({ space: $r('app.float.space_4') }) {
              this.fieldTitle('放在哪里', '位置会优先显示在列表中。')
              LocationInput({ locationPath: $locationPath })
              Text('分类（可选）')
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(CATEGORY_OPTIONS, (category: Category) => {
                  Button(category)
                    .type(ButtonType.Capsule)
                    .fontColor(this.categoryValue === category ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                    .backgroundColor(this.categoryValue === category ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                    .fontSize($r('app.float.font_caption'))
                    .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                    .onClick(() => this.categoryValue = this.categoryValue === category ? '' : category)
                }, (category: Category) => category)
              }
            }
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))

            Column({ space: $r('app.float.space_3') }) {
              this.fieldTitle('到期与提醒', '开启系统提醒后，保存时会按提前天数安排提醒。')
              Text('到期日期（可选）')
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              TextInput({ text: this.expirationDate, placeholder: 'YYYY-MM-DD' })
                .backgroundColor($r('app.color.surface_app'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .onChange((value: string) => this.expirationDate = value)
              Text('提前提醒天数（可选）')
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              TextInput({ text: this.reminderDaysText, placeholder: '未填写时按 7 天计算状态' })
                .type(InputType.Number)
                .backgroundColor($r('app.color.surface_app'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .onChange((value: string) => this.reminderDaysText = value)
            }
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))

            Column({ space: $r('app.float.space_3') }) {
              this.fieldTitle('注意事项', '例如服用方式、使用限制或收纳提醒。')
              TextArea({ text: this.notes, placeholder: '写下重要说明' })
                .maxLength(500)
                .backgroundColor($r('app.color.surface_app'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .onChange((value: string) => this.notes = value)
              Text('扫码结果（可选）')
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              TextInput({ text: this.scanText, placeholder: '可手动输入条码或二维码文本' })
                .backgroundColor($r('app.color.surface_app'))
                .border({ width: 1, color: $r('app.color.border_subtle') })
                .borderRadius($r('app.float.radius_control'))
                .onChange((value: string) => this.scanText = value)
              Row({ space: $r('app.float.space_2') }) {
                Button('启动扫码')
                  .layoutWeight(1)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .onClick(() => this.scanToText())
                Button('添加到备注')
                  .layoutWeight(1)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_app'))
                  .border({ width: 1, color: $r('app.color.border_subtle') })
                  .borderRadius($r('app.float.radius_control'))
                  .onClick(() => this.applyScanText())
              }
              .width('100%')
            }
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))

            Column({ space: $r('app.float.space_3') }) {
              this.fieldTitle('物品照片', this.pendingPhotoUri.length === 0 ? '可选择系统相册照片，或在系统选择器中拍摄。' : '已选择照片，保存物品后会复制到本机私有目录。')
              Row({ space: $r('app.float.space_2') }) {
                Button(this.photoPicking ? '正在打开选择器…' : '选择照片')
                  .layoutWeight(1)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .enabled(!this.photoPicking)
                  .onClick(() => this.selectPhoto())
                Button('拍摄照片')
                  .layoutWeight(1)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_app'))
                  .border({ width: 1, color: $r('app.color.border_subtle') })
                  .borderRadius($r('app.float.radius_control'))
                  .enabled(!this.photoPicking)
                  .onClick(() => this.capturePhoto())
              }
              .width('100%')
              if (this.pendingPhotoUri.length > 0) {
                Text('已选择 1 张照片；可重新选择后再保存。')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_success'))
              }
            }
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.status_danger'))
                .padding($r('app.float.space_3'))
                .borderRadius($r('app.float.radius_control'))
                .backgroundColor($r('app.color.status_danger_soft'))
            }
            Button(this.saving ? '正在保存…' : '保存物品')
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
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private fieldTitle(title: string, description: string) {
    Column({ space: $r('app.float.space_1') }) {
      Text(title)
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(description)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
  }

  private readRoute(): void {
    const params = NavigationHelper.getParams() as ItemFormRouteParams;
    if (!params) {
      this.errorMessage = '页面参数错误';
      this.loading = false;
      return;
    }
    this.editMode = params.mode === 'edit';
    if (!this.editMode) {
      return;
    }
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.errorMessage = itemIdResult.getError().message;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.loadExisting();
  }

  private async loadExisting(): Promise<void> {
    this.loading = true;
    const result = await AppServices.get().detailItem.getDetail(this.itemId);
    if (result.ok) {
      this.applyItem(result.getData());
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
  }

  private applyItem(item: Item): void {
    this.name = item.name;
    this.quantityText = item.quantity.toString();
    this.unit = item.unit;
    this.locationPath = item.locationPath ?? '';
    this.categoryValue = item.category ?? '';
    this.expirationDate = item.expirationDate ?? '';
    this.reminderDaysText = item.reminderDays === undefined ? '' : item.reminderDays.toString();
    this.notes = item.notes ?? '';
  }

  private async save(): Promise<void> {
    this.errorMessage = '';
    if (this.quantityError.length > 0) {
      this.errorMessage = this.quantityError;
      return;
    }
    const draft = this.createDraft();
    this.saving = true;
    try {
      if (this.editMode) {
        const result = await AppServices.get().updateItem.update(this.itemId, draft);
        if (result.ok) {
          const notice = await this.synchronizeAfterSave(result.getData());
          AppEventBus.notifyDataChanged();
          this.openItemList(notice);
          return;
        }
        this.errorMessage = result.getError().message;
      } else {
        const result = await AppServices.get().createItem.create(draft);
        if (result.ok) {
          const notice = await this.synchronizeAfterSave(result.getData());
          AppEventBus.notifyDataChanged();
          this.openItemList(notice);
          return;
        }
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '保存失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private openItemList(notice?: string): void {
    NavigationHelper.replaceUrl({ url: RouteName.ITEM_LIST, params: { notice: notice } }).catch(() => {
      NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { notice: notice } });
    });
  }

  private createDraft(): ItemDraft {
    const quantity = this.quantityText.trim().length === 0 ? undefined : Number(this.quantityText);
    const reminderDays = this.reminderDaysText.trim().length === 0 ? undefined : Number(this.reminderDaysText);
    return {
      name: this.name,
      quantity: quantity,
      unit: this.unit,
      locationPath: this.locationPath,
      category: this.categoryValue.length === 0 ? undefined : this.categoryValue as Category,
      expirationDate: this.expirationDate,
      reminderDays: reminderDays,
      notes: this.notes
    };
  }

  private async loadDefaultReminderDays(): Promise<void> {
    const result = await AppServices.get().preferences.get();
    if (result.ok && this.reminderDaysText.length === 0) {
      this.reminderDaysText = result.getData().defaultReminderDays.toString();
    }
  }

  private async selectPhoto(): Promise<void> {
    this.errorMessage = '';
    this.photoPicking = true;
    const result = await AppServices.get().imageSource.selectFromAlbum();
    if (result.ok) {
      const uri = result.getData();
      if (uri !== undefined) {
        this.pendingPhotoUri = uri;
        this.pendingPhotoSource = AssetSource.PHOTO_PICKER;
      }
    } else {
      this.errorMessage = result.getError().message;
    }
    this.photoPicking = false;
  }

  private async capturePhoto(): Promise<void> {
    this.errorMessage = '';
    this.photoPicking = true;
    const result = await AppServices.get().imageSource.captureWithSystemPicker();
    if (result.ok) {
      const uri = result.getData();
      if (uri !== undefined) {
        this.pendingPhotoUri = uri;
        this.pendingPhotoSource = AssetSource.SYSTEM_CAMERA;
      }
    } else {
      this.errorMessage = result.getError().message;
    }
    this.photoPicking = false;
  }

  private async synchronizeAfterSave(item: Item): Promise<string | undefined> {
    let currentItem = item;
    const notices: string[] = [];
    if (this.pendingPhotoUri.length > 0) {
      const photoResult = await AppServices.get().photos.attach(currentItem, this.pendingPhotoUri, this.pendingPhotoSource);
      if (photoResult.ok) {
        currentItem = photoResult.getData();
        this.pendingPhotoUri = '';
      } else {
        notices.push(`物品已保存，但${photoResult.getError().message}`);
      }
    }
    const reminderResult = await AppServices.get().reminders.reconcile(currentItem);
    if (!reminderResult.ok) {
      notices.push(`物品已保存，但${reminderResult.getError().message}`);
    }
    return notices.length === 0 ? undefined : notices.join('；');
  }

  private async scanToText(): Promise<void> {
    this.errorMessage = '';
    const result = await AppServices.get().scan.scan();
    if (!result.ok) {
      this.errorMessage = result.getError().message;
      return;
    }
    const scanText = result.getData();
    if (scanText !== undefined) {
      this.scanText = scanText;
    }
  }

  private applyScanText(): void {
    const normalized = this.scanText.trim();
    if (normalized.length === 0) {
      this.errorMessage = '请先输入或扫描文本';
      return;
    }
    const prefix = this.notes.trim().length === 0 ? '' : `${this.notes.trim()}\n`;
    this.notes = `${prefix}扫码信息：${normalized}`;
    this.scanText = '';
  }
}
