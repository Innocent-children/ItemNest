import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LocationInput } from '../components/LocationInput';
import { LocationSelector } from '../components/LocationSelector';
import { LoadingState } from '../components/LoadingState';
import { QuantityInput } from '../components/QuantityInput';
import { ITEM_UNIT_OPTIONS, Item, ItemDraft, ItemUnit } from '../model/Item';
import { AssetSource } from '../model/ItemAsset';
import { LocationRecord } from '../model/Location';
import { buildItemRefreshParams } from '../navigation/RefreshContract';
import { ItemFormRouteParams, requireItemId } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppEventBus } from '../common/AppEventBus';
import { AppServices } from '../service/AppServices';
import { activeCategoryNames, refreshedUnit } from '../service/ItemFlowPresentation';

@Component
export struct ItemFormPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private name: string = '';
  @State private quantityText: string = '1';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private locationPath: string = '';
  @State private categoryValue: string = '';
  @State private expirationDate: string = '';
  @State private reminderDaysText: string = '';
  @State private notes: string = '';
  @State private scanText: string = '';
  @State private scanning: boolean = false;
  @State private quantityError: string = '';
  @State private errorMessage: string = '';
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private savePressed: boolean = false;
  @State private batchManagePressed: boolean = false;
  @State private editMode: boolean = false;
  @State private itemId: string = '';
  @State private pendingPhotoUri: string = '';
  @State private existingPhotoLocalId: string = '';
  @State private managedLocations: LocationRecord[] = [];
  @State private categoryOptions: string[] = [];
  @State private categoryLoadError: string = '';
  @State private categoryLoading: boolean = false;
  @State private pendingPhotoSource: AssetSource = AssetSource.PHOTO_PICKER;
  @State private photoPicking: boolean = false;
  @State private showDiscardConfirm: boolean = false;
  @State @Watch('handleDiscardRequest') private discardConfirmed: boolean = false;
  @State private showCategorySection: boolean = false;
  @State private showExpirySection: boolean = false;
  @State private showNotesSection: boolean = false;
  @State private showPhotoSection: boolean = false;
  private loadedQuantityText: string = '1';
  private loadedUnit: ItemUnit = ItemUnit.PIECE;
  private loadedExpirationDate: string = '';
  private initialDraftSignature: string = '';
  private returnToRoute: string = RouteName.HOME;
  private backHandler: () => boolean = () => this.handleNavigationBack();
  private existingLoaded: boolean = false;
  private managedFieldsRequestId: number = 0;
  private categoryLoadRequestId: number = 0;

  aboutToAppear(): void {
    NavigationHelper.registerBackHandler(this.backHandler);
    this.readRoute();
    this.loadManagedLocations();
    this.loadCategoryOptions();
    if (!this.editMode) {
      this.markClean();
      this.loadDefaultReminderDays();
    }
  }

  aboutToDisappear(): void {
    NavigationHelper.unregisterBackHandler(this.backHandler);
  }

  onPageShow(): void {
    this.loadManagedLocations();
    this.loadCategoryOptions();
  }

  private onDataRevisionChanged(): void {
    this.loadCategoryOptions();
    if (this.editMode && this.existingLoaded && this.itemId.length > 0 && !this.saving) {
      this.refreshManagedBatchFields();
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
          LoadingState({ text: '正在读取物品…' })
        } else {
          Scroll() {
            Column({ space: $r('app.float.space_4') }) {
              this.coreSection()
              this.locationSection()

              this.sectionToggle('分类', this.categoryValue.length > 0 ? `当前：${this.categoryValue}` : '可选，用于筛选和整理', 'category')
              if (this.showCategorySection) {
                this.categorySection()
              }

              this.sectionToggle(
                '到期与提醒',
                this.editMode ? '到期日由批次汇总；提前提醒仍可编辑' : '设置保质期和提前提醒',
                'expiry'
              )
              if (this.showExpirySection) {
                this.expirySection()
              }

              this.sectionToggle('备注与条码', '补充注意事项或条码文本', 'notes')
              if (this.showNotesSection) {
                this.notesSection()
              }

              this.sectionToggle('物品照片', this.hasPhoto() ? '当前物品已有照片' : '选择或拍摄一张照片', 'photo')
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
      .constraintSize({ maxWidth: 800 })
      .height('100%')
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
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
      this.fieldTitle('基础信息', this.editMode ? '名称与单位可编辑；数量和到期日由批次管理。' : '数量填写目前拥有的总量，包含借出部分；借还可在保存后记录。')
      TextInput({ text: this.name, placeholder: '例如：感冒药' })
        .maxLength(80)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.name = value)
      if (this.editMode) {
        Text(`总量 ${this.quantityText}${this.unit}（包含借出）`)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        Text('统一修改单位')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(ITEM_UNIT_OPTIONS, (option: ItemUnit) => {
            Button(option)
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .type(ButtonType.Capsule)
              .fontColor(this.unit === option ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
              .backgroundColor(this.unit === option ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
              .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
              .enabled(!this.saving)
              .onClick(() => this.unit = option)
          }, (option: ItemUnit) => option)
        }
        Text('修改后所有批次和借还数量使用新单位，数值不会自动换算。')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        this.batchSourceNotice()
      } else {
        QuantityInput({ quantityText: $quantityText, unit: $unit, errorMessage: $quantityError })
      }
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
  }

  @Builder
  private batchSourceNotice() {
    Column({ space: $r('app.float.space_3') }) {
      Text('数量和到期日请在批次管理中修改；日常用量可在详情记录')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Button('进入批次管理')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .enabled(!this.saving && this.itemId.length > 0)
        .scale({ x: this.batchManagePressed && !this.reduceAnimation ? 0.96 : 1, y: this.batchManagePressed && !this.reduceAnimation ? 0.96 : 1 })
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.batchManagePressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.batchManagePressed = false;
          }
        })
        .onClick(() => this.openBatchManagement())
    }
    .width('100%')
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($r('app.color.surface_accent'))
  }

  @Builder
  private locationSection() {
    Column({ space: $r('app.float.space_4') }) {
      this.fieldTitle('默认位置', '批次未单独填写位置时使用这里；找物按仍有数量的批次显示。')
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
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
  }

  @Builder
  private categorySection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('分类（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (this.categoryLoadError.length > 0) {
        Text(this.categoryLoadError)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.status_danger'))
        Button(this.categoryLoading ? '正在读取…' : '重试读取分类')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .enabled(!this.categoryLoading)
          .onClick(() => this.loadCategoryOptions())
      } else if (this.categoryOptions.length === 0) {
        Text(this.categoryLoading ? '正在读取分类…' : '暂无启用的分类，可在设置中管理。')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (!this.categoryLoading && this.categoryLoadError.length === 0 && this.categoryValue.length > 0 && this.categoryOptions.indexOf(this.categoryValue) < 0) {
        Text(`原分类“${this.categoryValue}”不在启用列表中，可保留原值或重新选择。`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        Button('清除原分类')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .onClick(() => this.categoryValue = '')
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categoryOptions, (category: string) => {
          Button(category)
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
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
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .width('100%')
        .fontColor($r('app.color.brand_on_primary'))
        .backgroundColor($r('app.color.brand_primary'))
        .borderRadius($r('app.float.radius_control'))
        .enabled(!this.saving)
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
    .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_3'), bottom: $r('app.float.space_4') })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private sectionToggle(title: string, description: string, section: string) {
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
      Text(this.isSectionExpanded(section) ? '收起' : '展开')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.brand_primary'))
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
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
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.editMode && this.expirationDate.length > 0)
          .onClick(() => this.expirationDate = '')
      }
      .width('100%')
      .padding($r('app.float.space_3'))
      .borderRadius($r('app.float.radius_control'))
      .backgroundColor($r('app.color.surface_app'))
      CalendarPicker({ selected: this.expirationPickerDate() })
        .enabled(!this.editMode)
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
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
  }

  @Builder
  private reminderShortcut(label: string, value: string) {
    Button(label)
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
      .type(ButtonType.Capsule)
      .fontColor($r('app.color.brand_primary'))
      .backgroundColor($r('app.color.surface_accent'))
      .fontSize($r('app.float.font_caption'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .enabled(!this.editMode)
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
      Text('条码或二维码（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.scanText, placeholder: '扫描或手动输入' })
        .maxLength(256)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.scanText = value)
      Button(this.scanning ? '正在打开扫码…' : '扫描条码或二维码')
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
        .width('100%')
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .enabled(!this.scanning)
        .onClick(() => this.scanBarcode())
    }
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
  }

  @Builder
  private photoSection() {
    Column({ space: $r('app.float.space_3') }) {
      Text(this.hasPhoto() ? '当前物品已有照片；重新选择后保存会替换照片。' : '可选择系统相册照片，或在系统选择器中拍摄。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      Row({ space: $r('app.float.space_2') }) {
        Button(this.photoPicking ? '正在打开选择器…' : '选择照片')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.photoPicking)
          .onClick(() => this.selectPhoto())
        Button('拍摄照片')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
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
      this.existingLoaded = true;
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
    const requestId = ++this.categoryLoadRequestId;
    this.categoryLoading = true;
    try {
      const result = await AppServices.get().categories.list();
      if (requestId !== this.categoryLoadRequestId) {
        return;
      }
      if (!result.ok) {
        this.categoryOptions = [];
        this.categoryLoadError = result.getError().message;
        return;
      }
      this.categoryOptions = activeCategoryNames(result.getData());
      this.categoryLoadError = '';
    } catch (_) {
      if (requestId === this.categoryLoadRequestId) {
        this.categoryOptions = [];
        this.categoryLoadError = '读取分类失败，请重试';
      }
    } finally {
      if (requestId === this.categoryLoadRequestId) {
        this.categoryLoading = false;
      }
    }
  }

  private applyItem(item: Item): void {
    this.name = item.name;
    this.loadedQuantityText = item.quantity.toString();
    this.loadedUnit = item.unit;
    this.loadedExpirationDate = item.expirationDate ?? '';
    this.quantityText = this.loadedQuantityText;
    this.unit = this.loadedUnit;
    this.locationPath = item.locationPath ?? '';
    this.categoryValue = item.category ?? '';
    this.expirationDate = this.loadedExpirationDate;
    this.reminderDaysText = item.reminderDays === undefined ? '' : item.reminderDays.toString();
    this.notes = item.notes ?? '';
    this.scanText = item.barcode ?? '';
    this.existingPhotoLocalId = item.photoLocalId ?? '';
    this.showCategorySection = this.categoryValue.length > 0;
    this.showExpirySection = this.expirationDate.length > 0 || this.reminderDaysText.length > 0;
    this.showNotesSection = this.notes.length > 0 || this.scanText.length > 0;
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
    this.savePressed = false;
    this.errorMessage = '';
    if (this.quantityError.length > 0) {
      this.errorMessage = this.quantityError;
      return;
    }
    this.saving = true;
    try {
      if (this.editMode) {
        this.managedFieldsRequestId++;
        const latestResult = await AppServices.get().detailItem.getDetail(this.itemId);
        if (!latestResult.ok) {
          this.errorMessage = latestResult.getError().message;
          return;
        }
        this.applyManagedBatchFields(latestResult.getData());
        const draft = this.createDraft();
        const result = await AppServices.get().updateItem.update(this.itemId, draft);
        if (result.ok) {
          this.itemId = result.getData().id;
          const notice = await this.synchronizeAfterSave(result.getData());
          this.finishSave(notice);
          return;
        }
        this.errorMessage = result.getError().message;
      } else {
        const draft = this.createDraft();
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

  private async openBatchManagement(): Promise<void> {
    if (this.itemId.length === 0 || this.saving) {
      return;
    }
    const opened = await NavigationHelper.pushUrl({ url: RouteName.BATCH_LIST, params: { itemId: this.itemId } });
    if (!opened) {
      this.errorMessage = '批次管理暂时无法打开，请重试';
    }
  }

  private async refreshManagedBatchFields(): Promise<void> {
    const requestId = ++this.managedFieldsRequestId;
    try {
      const result = await AppServices.get().detailItem.getDetail(this.itemId);
      if (requestId !== this.managedFieldsRequestId) {
        return;
      }
      if (!result.ok) {
        this.errorMessage = result.getError().message;
        return;
      }
      this.applyManagedBatchFields(result.getData());
    } catch (_) {
      if (requestId === this.managedFieldsRequestId) {
        this.errorMessage = '刷新批次汇总失败，请重试';
      }
    }
  }

  private applyManagedBatchFields(item: Item): void {
    const nextUnit = refreshedUnit(this.unit, this.loadedUnit, item.unit);
    this.loadedQuantityText = item.quantity.toString();
    this.loadedUnit = item.unit;
    this.loadedExpirationDate = item.expirationDate ?? '';
    this.quantityText = this.loadedQuantityText;
    this.unit = nextUnit;
    this.expirationDate = this.loadedExpirationDate;
  }

  private finishSave(notice?: string): void {
    this.showToast(notice ?? '物品已保存');
    const refreshAt = AppEventBus.notifyDataChanged();
    NavigationHelper.back({
      url: this.returnToRoute,
      params: buildItemRefreshParams(refreshAt, this.itemId)
    });
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
    const quantityText = this.editMode ? this.loadedQuantityText : this.quantityText;
    const quantity = quantityText.trim().length === 0 ? undefined : Number(quantityText);
    const reminderDays = this.reminderDaysText.trim().length === 0 ? undefined : Number(this.reminderDaysText);
    return {
      name: this.name,
      quantity: quantity,
      unit: this.unit,
      locationPath: this.locationPath,
      category: this.categoryValue.length === 0 ? undefined : this.categoryValue,
      expirationDate: this.editMode ? this.loadedExpirationDate : this.expirationDate,
      reminderDays: reminderDays,
      notes: this.notes,
      barcode: this.scanText
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
      name: this.name,
      quantityText: this.editMode ? '' : this.quantityText,
      unit: this.unit,
      locationPath: this.locationPath,
      categoryValue: this.categoryValue,
      expirationDate: this.editMode ? '' : this.expirationDate,
      reminderDaysText: this.reminderDaysText,
      notes: this.notes,
      scanText: this.scanText,
      pendingPhotoUri: this.pendingPhotoUri
    });
  }

  private toggleSection(section: string): void {
    if (this.reduceAnimation) {
      this.setSectionExpanded(section);
      return;
    }
    this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.76), () => this.setSectionExpanded(section));
  }

  private isSectionExpanded(section: string): boolean {
    if (section === 'category') {
      return this.showCategorySection;
    }
    if (section === 'expiry') {
      return this.showExpirySection;
    }
    if (section === 'notes') {
      return this.showNotesSection;
    }
    return this.showPhotoSection;
  }

  private setSectionExpanded(section: string): void {
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
    try {
      const reminderResult = await AppServices.get().reminders.reconcileLatest(currentItem.id);
      if (!reminderResult.ok) {
        notices.push(`物品已保存，提醒更新失败：${reminderResult.getError().message}；可在详情重试`);
      }
    } catch (_) {
      notices.push('物品已保存，提醒更新失败；可在详情重试');
    }
    return notices.length === 0 ? undefined : notices.join('；');
  }

  private async scanBarcode(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      this.showToast('扫码暂不可用，请手动输入');
      return;
    }
    this.scanning = true;
    try {
      const result = await AppServices.get().scan.scan(hostContext);
      if (!result.ok) {
        this.showToast(result.getError().message);
        return;
      }
      if (result.getData() !== undefined) {
        const scanned = result.getData() ?? '';
        if (scanned.length > 256) {
          this.showToast('条码内容超过 256 个字符，请手动整理后输入');
        } else {
          this.scanText = scanned;
        }
      }
    } catch (_) {
      this.showToast('扫码暂不可用，请手动输入');
    } finally {
      this.scanning = false;
    }
  }
}
