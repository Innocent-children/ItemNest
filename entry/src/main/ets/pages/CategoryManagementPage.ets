import { NavigationHelper } from '../navigation/NavigationHelper';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, nativeTitleOptions, nativeSheetOptions } from '../ui/VisualStyle';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { CategoryRecord } from '../model/Category';
import { AppServices } from '../service/AppServices';

@Component
export struct CategoryManagementPage {
  private pageScroller: Scroller = new Scroller();
  @State private showCreateSheet: boolean = false;
  @State private viewportWidth: number = 360;
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @State private loading: boolean = true;
  @State private operating: boolean = false;
  @State private loadError: string = '';
  @State private actionError: string = '';
  @State private pressedAction: string = '';
  @State private name: string = '';
  @State private categories: CategoryRecord[] = [];
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.loadCategoriesForCurrentRevision(true);
  }

  onPageShow(): void {
    this.refreshForRevisionChange(false);
  }

  private onDataRevisionChanged(): void {
    this.refreshForRevisionChange(false);
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    if (dataRevision === this.lastHandledDataRevision) {
      return false;
    }
    this.loadCategoriesForCurrentRevision(showLoading);
    return true;
  }

  private loadCategoriesForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadCategories(showLoading);
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
    PageHeader({ title: '物品分类', subtitle: '按你的习惯，把物品整理好。', showBack: true,
        actionText: '新增分类', actionIcon: $r('app.media.dock_add'), actionEnabled: !this.operating && !this.loading,
        onAction: () => { this.actionError = ''; this.showCreateSheet = true; } })
  }

  @Builder
  private pageContent() {
    Column() {

      if (this.loading) {
        LoadingState({ text: '正在读取分类…' })
      } else {
        Scroll(this.pageScroller) {
          Column({ space: $r('app.float.space_4') }) {
            if (this.actionError.length > 0) {
              ErrorState({ message: this.actionError })
            } else if (this.loadError.length > 0) {
              ErrorState({ message: this.loadError })
            }
            Text('全部分类').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%').margin({ top: 12 })
            ForEach(this.categories, (category: CategoryRecord) => {
              Row() {
                Image($r('app.media.ui_category')).width(24).height(24)
                  .fillColor($r('app.color.brand_primary')).margin({ right: 14 }).accessibilityLevel('no')
                Column({ space: $r('app.float.space_1') }) {
                  Text(category.name)
                    .fontSize($r('app.float.font_body'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(`${category.systemPreset ? '系统分类' : '自定义分类'} · ${category.active ? '可用' : '已停用'}`)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button(category.active ? '停用' : '启用')
                  .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .enabled(!this.operating)
                  .scale({
                    x: this.pressedAction === `toggle:${category.id}` && !this.reduceAnimation ? 0.96 : 1,
                    y: this.pressedAction === `toggle:${category.id}` && !this.reduceAnimation ? 0.96 : 1
                  })
                  .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                  .onTouch((event: TouchEvent) => this.updatePressedAction(event, `toggle:${category.id}`))
                  .onClick(() => this.toggleCategory(category))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (category: CategoryRecord) => `${category.id}:${category.updatedAt}:${category.active}`)
          }
          .width('100%')
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
        }.clip(false)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%').constraintSize({ maxWidth: 960 })
    .padding({ bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showCreateSheet, this.createSheet(), nativeSheetOptions({
      height: SheetSize.FIT_CONTENT, dragBar: true, showClose: true,
      title: { title: '新增分类' }, backgroundColor: $r('app.color.surface_app'),
      preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined,
      onWillDismiss: (action: DismissSheetAction) => { if (!this.operating) { action.dismiss(); } }
    }, this.reduceAnimation))
  }

  @Builder
  private createSheet() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          TextInput({ text: this.name, placeholder: '新增分类名称' })
            .borderWidth(1)
            .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'name'))
            .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
              if (this.focusedField === 'name') { this.focusedField = ''; }
            }))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_control'))
            .enabled(!this.operating)
            .borderColor(this.focusedField === 'name' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onChange((value: string) => this.name = value)

          if (this.actionError.length > 0) { ErrorState({ message: this.actionError }) }
        }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Row() {
        Button('新增分类')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width('100%')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.operating)
          .scale({ x: this.pressedAction === 'create' && !this.reduceAnimation ? 0.96 : 1, y: this.pressedAction === 'create' && !this.reduceAnimation ? 0.96 : 1 })
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .onTouch((event: TouchEvent) => this.updatePressedAction(event, 'create'))
          .onClick(() => this.createCategory())
      }.width('100%').padding({ left: 24, right: 24, bottom: 24 })
    }.width('100%')
  }

  private async loadCategories(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
      this.loadError = '';
    }
    try {
      const result = await AppServices.get().categories.list();
      if (result.ok) {
        this.categories = result.getData();
        this.loadError = '';
      } else {
        this.loadError = result.getError().message;
      }
    } catch (_) {
      this.loadError = '读取分类失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private async createCategory(): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().categories.create({ name: this.name });
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.showCreateSheet = false;
      this.name = '';
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadCategories(false);
      this.showToast('分类已新增');
    } catch (_) {
      this.actionError = '新增分类失败，请稍后重试';
    } finally {
      this.operating = false;
    }
  }

  private async toggleCategory(category: CategoryRecord): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().categories.setActive(category.id, !category.active);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadCategories(false);
      this.showToast(category.active ? '分类已停用' : '分类已启用');
    } catch (_) {
      this.actionError = category.active ? '停用分类失败，请稍后重试' : '启用分类失败，请稍后重试';
    } finally {
      this.operating = false;
    }
  }

  private updatePressedAction(event: TouchEvent, action: string): void {
    if (event.type === TouchType.Down) {
      this.pressedAction = action;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedAction = '';
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
