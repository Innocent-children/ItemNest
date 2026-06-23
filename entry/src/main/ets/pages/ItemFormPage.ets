import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LocationInput } from '../components/LocationInput';
import { LocationSelector } from '../components/LocationSelector';
import { LoadingState } from '../components/LoadingState';
import { QuantityInput } from '../components/QuantityInput';
import { CATEGORY_OPTIONS, CategoryRecord } from '../model/Category';
import { Item, ItemDraft, ItemUnit } from '../model/Item';
import { AssetSource } from '../model/ItemAsset';
import { LocationRecord } from '../model/Location';
import { ItemFormRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppEventBus } from '../common/AppEventBus';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct ItemFormPage {
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
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
  @State private existingPhotoLocalId: string = '';
  @State private managedLocations: LocationRecord[] = [];
  @State private categoryOptions: string[] = CATEGORY_OPTIONS.slice();
  @State private pendingPhotoSource: AssetSource = AssetSource.PHOTO_PICKER;
  @State private photoPicking: boolean = false;
  @State private showDiscardConfirm: boolean = false;
  @State @Watch('handleDiscardRequest') private discardConfirmed: boolean = false;
  @State private showCategorySection: boolean = false;
  @State private showExpirySection: boolean = false;
  @State private showNotesSection: boolean = false;
  @State private showPhotoSection: boolean = false;
  private initialDraftSignature: string = '';
  private returnToRoute: string = RouteName.HOME;

  aboutToAppear(): void {
    this.readRoute();
    this.loadManagedLocations();
    this.loadCategoryOptions();
    if (!this.editMode) {
      this.markClean();
      this.loadDefaultReminderDays();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Column({ space: $r('app.float.space_1') }) {
            Text(this.editMode ? '编辑物品' : '记录新物品')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.editMode ? '更新后，所有列表和摘要会同步刷新。' : '先记录最重要的信息，其他内容随时补充。')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
          }
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
          LoadingState({ text: '正在读取物品…' })
        } else {
          Scroll() {
            Column({ space: $r('app.float.space_4') }) {
              this.coreSection()
              this.locationSection()

              this.sectionToggle('分类', this.categoryValue.length > 0 ? `当前：${this.categoryValue}` : '可选，用于筛选和整理', this.showCategorySection, 'category')
              if (this.showCategorySection) {
                this.categorySection()
              }

              this.sectionToggle('到期与提醒', '设置保质期和提前提醒', this.showExpirySection, 'expiry')
              if (this.showExpirySection) {
                this.expirySection()
              }

              this.sectionToggle('备注与条码', '补充注意事项或条码文本', this.showNotesSection, 'notes')
              if (this.showNotesSection) {
                this.notesSection()
              }

              this.sectionToggle('物品照片', this.hasPhoto() ? '当前物品已有照片' : '选择或拍摄一张照片', this.showPhotoSection, 'photo')
              if (this.showPhotoSection) {
                this.photoSection()
              }

            }
            .width('100%')
            .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_4') })
          }
          .layoutWeight(1)

          this.saveBar()
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
        description: '当前填写的内容尚未保存，放弃后无法恢复。',
        confirmText: '放弃编辑'
      })
    }
    .width('100%')
    .height('100%')
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

  @Builder
  private coreSection() {
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
  }

  @Builder
  private locationSection() {
    Column({ space: $r('app.float.space_4') }) {
      this.fieldTitle('放在哪里', '位置会优先显示在列表中。')
      LocationInput({ locationPath: $locationPath })
      if (this.managedLocations.length > 0) {
        Text('常用位置')
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        LocationSelector({ selectedPath: $locationPath, locations: this.managedLocations })
      }
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private categorySection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('分类（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categoryOptions, (category: string) => {
          Button(category)
            .type(ButtonType.Capsule)
            .fontColor(this.categoryValue === category ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
            .backgroundColor(this.categoryValue === category ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
            .fontSize($r('app.float.font_caption'))
            .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
            .onClick(() => this.categoryValue = this.categoryValue === category ? '' : category)
        }, (category: string) => category)
      }
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private saveBar() {
    Column({ space: $r('app.float.space_2') }) {
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
    .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_3'), bottom: $r('app.float.space_4') })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private sectionToggle(title: string, description: string, expanded: boolean, section: string) {
    Row() {
      Column({ space: $r('app.float.space_1') }) {
        Text(title)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(description)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      Text(expanded ? '收起' : '展开')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.brand_primary'))
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .onClick(() => this.toggleSection(section))
  }

  @Builder
  private expirySection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('到期日期（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Row() {
        Text(this.expirationDate.length === 0 ? '未设置到期日期' : this.expirationDate)
          .fontSize($r('app.float.font_body'))
          .fontColor(this.expirationDate.length === 0 ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
          .layoutWeight(1)
        Button('清除')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(this.expirationDate.length > 0)
          .onClick(() => this.expirationDate = '')
      }
      .width('100%')
      .padding($r('app.float.space_3'))
      .borderRadius($r('app.float.radius_control'))
      .backgroundColor($r('app.color.surface_app'))
      CalendarPicker({ selected: this.expirationPickerDate() })
        .onChange((date: Date) => this.expirationDate = this.formatDate(date))
      Flex({ wrap: FlexWrap.Wrap }) {
        this.expirationShortcut('今天', 0)
        this.expirationShortcut('30 天后', 30)
        this.expirationShortcut('清除日期', -1)
      }
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
      Flex({ wrap: FlexWrap.Wrap }) {
        this.reminderShortcut('当天', '0')
        this.reminderShortcut('提前 3 天', '3')
        this.reminderShortcut('提前 7 天', '7')
      }
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private reminderShortcut(label: string, value: string) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontColor(this.reminderDaysText === value ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
      .backgroundColor(this.reminderDaysText === value ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
      .fontSize($r('app.float.font_caption'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => this.reminderDaysText = value)
  }

  @Builder
  private expirationShortcut(label: string, offsetDays: number) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontColor($r('app.color.brand_primary'))
      .backgroundColor($r('app.color.surface_accent'))
      .fontSize($r('app.float.font_caption'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => {
        if (offsetDays < 0) {
          this.expirationDate = '';
          return;
        }
        const date = new Date();
        date.setDate(date.getDate() + offsetDays);
        this.expirationDate = this.formatDate(date);
      })
  }

  @Builder
  private notesSection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('注意事项')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextArea({ text: this.notes, placeholder: '写下重要说明' })
        .maxLength(500)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.notes = value)
      Text('条码/二维码文本（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.scanText, placeholder: '手动输入条码或二维码文本' })
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.scanText = value)
      Button('添加到备注')
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onClick(() => this.applyScanText())
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  @Builder
  private photoSection() {
    Column({ space: $r('app.float.space_3') }) {
      Text(this.hasPhoto() ? '当前物品已有照片；重新选择后保存会替换照片。' : '可选择系统相册照片，或在系统选择器中拍摄。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
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
      if (this.hasPhoto()) {
        Text(this.pendingPhotoUri.length > 0 ? '已选择 1 张新照片；保存后生效。' : '已关联 1 张照片。')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.status_success'))
      }
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
  }

  private readRoute(): void {
    const params = NavigationHelper.getParams() as ItemFormRouteParams | undefined;
    this.editMode = params?.mode === 'edit';
    this.returnToRoute = params?.returnTo ?? (this.editMode ? RouteName.ITEM_DETAIL : RouteName.HOME);
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
      this.markClean();
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
  }

  private async loadManagedLocations(): Promise<void> {
    const result = await AppServices.get().locations.list();
    if (result.ok) {
      this.managedLocations = result.getData();
    }
  }

  private async loadCategoryOptions(): Promise<void> {
    const result = await AppServices.get().categories.list();
    if (!result.ok) {
      this.categoryOptions = CATEGORY_OPTIONS.slice();
      return;
    }
    const options: string[] = CATEGORY_OPTIONS.slice();
    const categories = result.getData();
    for (let index = 0; index < categories.length; index++) {
      const category: CategoryRecord = categories[index];
      if (category.active && options.indexOf(category.name) < 0) {
        options.push(category.name);
      }
    }
    this.categoryOptions = options;
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
    this.existingPhotoLocalId = item.photoLocalId ?? '';
    this.showCategorySection = this.categoryValue.length > 0;
    this.showExpirySection = this.expirationDate.length > 0 || this.reminderDaysText.length > 0;
    this.showNotesSection = this.notes.length > 0;
    this.showPhotoSection = this.existingPhotoLocalId.length > 0;
  }

  private expirationPickerDate(): Date {
    const parsed = this.parseDate(this.expirationDate);
    return parsed ?? new Date();
  }

  private parseDate(value: string): Date | undefined {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return undefined;
    }
    const year = Number(value.substring(0, 4));
    const month = Number(value.substring(5, 7));
    const day = Number(value.substring(8, 10));
    const date = new Date(year, month - 1, day);
    if (date.getFullYear() !== year || date.getMonth() + 1 !== month || date.getDate() !== day) {
      return undefined;
    }
    return date;
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear().toString();
    const month = this.twoDigits(date.getMonth() + 1);
    const day = this.twoDigits(date.getDate());
    return `${year}-${month}-${day}`;
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
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
          this.itemId = result.getData().id;
          const notice = await this.synchronizeAfterSave(result.getData());
          this.finishSave(notice);
          return;
        }
        this.errorMessage = result.getError().message;
      } else {
        const result = await AppServices.get().createItem.create(draft);
        if (result.ok) {
          this.itemId = result.getData().id;
          const notice = await this.synchronizeAfterSave(result.getData());
          this.finishSave(notice);
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

  private finishSave(notice?: string): void {
    this.showToast(notice ?? '物品已保存');
    NavigationHelper.back({
      url: this.returnToRoute,
      params: {
        refreshAt: Date.now(),
        itemId: this.itemId
      }
    });
    AppEventBus.notifyDataChangedAfterNavigation();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      });
    } catch (_) {
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
      category: this.categoryValue.length === 0 ? undefined : this.categoryValue,
      expirationDate: this.expirationDate,
      reminderDays: reminderDays,
      notes: this.notes
    };
  }

  private async loadDefaultReminderDays(): Promise<void> {
    const result = await AppServices.get().preferences.get();
    if (result.ok && this.reminderDaysText.length === 0 && this.currentDraftSignature() === this.initialDraftSignature) {
      this.reminderDaysText = result.getData().defaultReminderDays.toString();
      this.markClean();
    }
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
      name: this.name,
      quantityText: this.quantityText,
      unit: this.unit,
      locationPath: this.locationPath,
      categoryValue: this.categoryValue,
      expirationDate: this.expirationDate,
      reminderDaysText: this.reminderDaysText,
      notes: this.notes,
      scanText: this.scanText,
      pendingPhotoUri: this.pendingPhotoUri
    });
  }

  private toggleSection(section: string): void {
    if (section === 'category') {
      this.showCategorySection = !this.showCategorySection;
    } else if (section === 'expiry') {
      this.showExpirySection = !this.showExpirySection;
    } else if (section === 'notes') {
      this.showNotesSection = !this.showNotesSection;
    } else if (section === 'photo') {
      this.showPhotoSection = !this.showPhotoSection;
    }
  }

  private hasPhoto(): boolean {
    return this.pendingPhotoUri.length > 0 || this.existingPhotoLocalId.length > 0;
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
        this.showPhotoSection = true;
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
        this.showPhotoSection = true;
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

  private applyScanText(): void {
    const normalized = this.scanText.trim();
    if (normalized.length === 0) {
      this.errorMessage = '请先输入条码或二维码文本';
      return;
    }
    const prefix = this.notes.trim().length === 0 ? '' : `${this.notes.trim()}\n`;
    this.notes = `${prefix}条码信息：${normalized}`;
    this.scanText = '';
  }
}
