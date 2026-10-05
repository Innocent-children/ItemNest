import { NavigationHelper } from '../navigation/NavigationHelper';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, uiReveal, nativeTitleOptions, nativeSheetOptions } from '../ui/VisualStyle';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LocationRecord } from '../model/Location';
import { AppServices } from '../service/AppServices';

@Component
export struct LocationManagementPage {
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
  @State private selectedParentId: string = '';
  @State private collapsedLocations: string[] = [];
  @State private locations: LocationRecord[] = [];
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.loadLocationsForCurrentRevision(true);
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
    this.loadLocationsForCurrentRevision(showLoading);
    return true;
  }

  private loadLocationsForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadLocations(showLoading);
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
    PageHeader({ title: '存放位置', subtitle: '给每个角落一个名字。', showBack: true,
        actionText: '新增位置', actionIcon: $r('app.media.dock_add'), actionEnabled: !this.operating && !this.loading,
        onAction: () => { this.actionError = ''; this.showCreateSheet = true; } })
  }

  @Builder
  private pageContent() {
    Column() {

      if (this.loading) {
        LoadingState({ text: '正在读取位置…' })
      } else {
        Scroll(this.pageScroller) {
          Column({ space: $r('app.float.space_4') }) {
            if (this.actionError.length > 0) {
              ErrorState({ message: this.actionError })
            } else if (this.loadError.length > 0) {
              ErrorState({ message: this.loadError })
            }
            Text('全部位置').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%').margin({ top: 12 })
            ForEach(this.visibleLocations(), (location: LocationRecord) => {
              Row() {
                if (this.locations.some((child: LocationRecord) => child.parentId === location.id)) {
                  Button({ type: ButtonType.Normal }) {
                    Image($r('app.media.ui_chevron')).width(16).height(16).fillColor($r('app.color.brand_primary'))
                      .rotate({ angle: this.collapsedLocations.indexOf(location.id) >= 0 ? 0 : 90 })
                      .animation(uiSpring(this.reduceAnimation))
                  }.width(44).height(44).backgroundColor(Color.Transparent)
                    .accessibilityText(this.collapsedLocations.indexOf(location.id) >= 0 ? '展开子位置' : '收起子位置')
                    .onClick(() => this.toggleChildren(location.id))
                }
                Image($r('app.media.ui_location')).width(24).height(24)
                  .fillColor($r('app.color.brand_primary')).margin({ right: 14 }).accessibilityLevel('no')
                Column({ space: $r('app.float.space_1') }) {
                  Text(location.path)
                    .fontSize($r('app.float.font_body'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(location.active ? '可用' : '已停用')
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button(location.active ? '停用' : '启用')
                  .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .enabled(!this.operating)
                  .scale({
                    x: this.pressedAction === `toggle:${location.id}` && !this.reduceAnimation ? 0.96 : 1,
                    y: this.pressedAction === `toggle:${location.id}` && !this.reduceAnimation ? 0.96 : 1
                  })
                  .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                  .onTouch((event: TouchEvent) => this.updatePressedAction(event, `toggle:${location.id}`))
                  .onClick(() => this.toggleLocation(location))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
              .transition(uiReveal(this.reduceAnimation))
            }, (location: LocationRecord) => `${location.id}:${location.updatedAt}:${location.active}`)
          }
          .width('100%')
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
        }.clip(false).align(Alignment.TopStart)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%').constraintSize({ maxWidth: 960 })
    .padding({ bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showCreateSheet, this.createSheet(), nativeSheetOptions({
      height: SheetSize.LARGE, dragBar: true, showClose: true,
      title: { title: '新增位置' }, backgroundColor: $r('app.color.surface_app'),
      preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined,
      onWillDismiss: (action: DismissSheetAction) => { if (!this.operating) { action.dismiss(); } }
    }, this.reduceAnimation))
    }

  private visibleLocations(): LocationRecord[] {
    const records = new Map<string, LocationRecord>();
    this.locations.forEach((location: LocationRecord) => records.set(location.id, location));
    return this.locations.filter((location: LocationRecord) => {
      let parentId = location.parentId;
      while (parentId !== undefined && parentId.length > 0) {
        if (this.collapsedLocations.indexOf(parentId) >= 0) { return false; }
        parentId = records.get(parentId)?.parentId;
      }
      return true;
    });
  }

  private toggleChildren(locationId: string): void {
    this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => {
      this.collapsedLocations = this.collapsedLocations.indexOf(locationId) >= 0 ?
        this.collapsedLocations.filter((id: string) => id !== locationId) : this.collapsedLocations.concat([locationId]);
    });
  }

  @Builder
  private createSheet() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          TextInput({ text: this.name, placeholder: '新增位置名称' })
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
          Text('放在哪个位置下面？').fontSize(13).fontColor($r('app.color.text_secondary')).width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            Button('无父级')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .type(ButtonType.Capsule)
              .fontColor(this.selectedParentId.length === 0 ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
              .backgroundColor(this.selectedParentId.length === 0 ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
              .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
              .enabled(!this.operating)
              .onClick(() => this.selectedParentId = '')
            ForEach(this.locations, (location: LocationRecord) => {
              if (location.active) {
                Button(location.path)
                  .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                  .type(ButtonType.Capsule)
                  .fontColor(this.selectedParentId === location.id ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                  .backgroundColor(this.selectedParentId === location.id ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                  .fontSize($r('app.float.font_caption'))
                  .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                  .enabled(!this.operating)
                  .onClick(() => this.selectedParentId = this.selectedParentId === location.id ? '' : location.id)
              }
            }, (location: LocationRecord) => `${location.id}:${location.updatedAt}:${location.active}`)
          }

          if (this.actionError.length > 0) { ErrorState({ message: this.actionError }) }
        }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).width('100%').layoutWeight(1)
      Row() {
        Button('新增位置')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width('100%')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.operating)
          .scale({ x: this.pressedAction === 'create' && !this.reduceAnimation ? 0.96 : 1, y: this.pressedAction === 'create' && !this.reduceAnimation ? 0.96 : 1 })
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .onTouch((event: TouchEvent) => this.updatePressedAction(event, 'create'))
          .onClick(() => this.createLocation())
      }.width('100%').padding({ left: 24, right: 24, bottom: 24 })
    }.width('100%').height('100%')
  }

  private async loadLocations(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
      this.loadError = '';
    }
    try {
      const result = await AppServices.get().locations.list();
      if (result.ok) {
        this.locations = result.getData();
        this.loadError = '';
      } else {
        this.loadError = result.getError().message;
      }
    } catch (_) {
      this.loadError = '读取位置失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private async createLocation(): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().locations.create({
        name: this.name,
        parentId: this.selectedParentId.length === 0 ? undefined : this.selectedParentId
      });
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.showCreateSheet = false;
      this.name = '';
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadLocations(false);
      this.showToast('位置已新增');
    } catch (_) {
      this.actionError = '新增位置失败，请稍后重试';
    } finally {
      this.operating = false;
    }
  }

  private async toggleLocation(location: LocationRecord): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = location.active ? await AppServices.get().locations.deactivate(location.id) : await AppServices.get().locations.activate(location.id);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadLocations(false);
      this.showToast(location.active ? '位置已停用' : '位置已启用');
    } catch (_) {
      this.actionError = location.active ? '停用位置失败，请稍后重试' : '启用位置失败，请稍后重试';
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
