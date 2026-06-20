import { router } from '@kit.ArkUI';
import { EmptyState } from '../components/EmptyState';
import { LocationInput } from '../components/LocationInput';
import { LoadingState } from '../components/LoadingState';
import { QuantityInput } from '../components/QuantityInput';
import { CATEGORY_OPTIONS, Category } from '../model/Category';
import { Item, ItemDraft, ItemUnit } from '../model/Item';
import { ItemFormRouteParams, createItemResult, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
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
  @State private quantityError: string = '';
  @State private errorMessage: string = '';
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private editMode: boolean = false;
  @State private itemId: string = '';

  aboutToAppear(): void {
    this.readRoute();
  }

  build() {
    Column() {
      Text(this.editMode ? '编辑物品' : '新增物品')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding(16)
      if (this.loading) {
        LoadingState({ text: '正在读取物品…' })
      } else {
        Scroll() {
          Column({ space: 18 }) {
            this.fieldTitle('物品名称（必填）')
            TextInput({ text: this.name, placeholder: '例如：感冒药' })
              .maxLength(80)
              .onChange((value: string) => this.name = value)

            QuantityInput({ quantityText: $quantityText, unit: $unit, errorMessage: $quantityError })
            LocationInput({ locationPath: $locationPath })

            this.fieldTitle('分类（可选）')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(CATEGORY_OPTIONS, (category: Category) => {
                Button(category)
                  .type(this.categoryValue === category ? ButtonType.Capsule : ButtonType.Normal)
                  .fontSize(13)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => this.categoryValue = this.categoryValue === category ? '' : category)
              }, (category: Category) => category)
            }

            this.fieldTitle('到期日期（可选）')
            TextInput({ text: this.expirationDate, placeholder: 'YYYY-MM-DD' })
              .onChange((value: string) => this.expirationDate = value)
            this.fieldTitle('提前提醒天数（可选）')
            TextInput({ text: this.reminderDaysText, placeholder: '未填写时按 7 天计算状态' })
              .type(InputType.Number)
              .onChange((value: string) => this.reminderDaysText = value)
            this.fieldTitle('注意事项（可选）')
            TextArea({ text: this.notes, placeholder: '例如：饭后服用' })
              .maxLength(500)
              .onChange((value: string) => this.notes = value)

            this.fieldTitle('物品照片')
            EmptyState({ title: '暂未添加照片', description: '照片功能将在后续阶段提供。' })

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(14)
                .fontColor('#B42318')
            }
            Button(this.saving ? '正在保存…' : '保存物品')
              .width('100%')
              .enabled(!this.saving)
              .onClick(() => this.save())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  @Builder
  private fieldTitle(value: string) {
    Text(value)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .width('100%')
  }

  private readRoute(): void {
    const params = router.getParams() as ItemFormRouteParams;
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
          router.back({ url: RouteName.ITEM_LIST, params: createItemResult('updated', result.getData().id) });
          return;
        }
        this.errorMessage = result.getError().message;
      } else {
        const result = await AppServices.get().createItem.create(draft);
        if (result.ok) {
          router.back({ url: RouteName.ITEM_LIST, params: createItemResult('created', result.getData().id) });
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
}
