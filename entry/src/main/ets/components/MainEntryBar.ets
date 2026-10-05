import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { uiSpring } from '../ui/VisualStyle';

interface DockTabParams {
  label: string;
  route: string;
  icon: Resource;
}

@Component
export struct MainEntryBar {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @Prop activeRoute: string = RouteName.HOME;
  onTabSelected: (route: string) => void = (_route: string): void => {};
  @State private pressedRoute: string = '';
  @State private addPressed: boolean = false;

  build() {
    if (!this.keyboardVisible) {
      Row() {
        Row() {
          this.navButton({ label: '首页', route: RouteName.HOME, icon: $r('app.media.dock_home') })
          this.navButton({ label: '物品', route: RouteName.ITEM_LIST, icon: $r('app.media.dock_items') })
          this.addButton()
          this.navButton({ label: '搜索', route: RouteName.SEARCH, icon: $r('app.media.dock_search') })
          this.navButton({ label: '设置', route: RouteName.SETTINGS, icon: $r('app.media.dock_settings') })
        }
        .width('100%')
        .constraintSize({ maxWidth: 420 })
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.dock_glass'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, {
          policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
          inactiveColor: $r('app.color.surface_card')
        })
        .border({ width: 0.8, color: $r('app.color.glass_border') })
        .borderRadius($r('app.float.radius_pill'))
        .shadow({ radius: 20, color: $r('app.color.shadow_dock'), offsetY: 6 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 24, right: 24, top: 8, bottom: 12 })
    }
  }

  @Builder
  private navButton($$: DockTabParams) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Image($$.icon)
          .width(24)
          .height(24)
          .fillColor(this.activeRoute === $$.route ? $r('app.color.brand_primary') : $r('app.color.text_primary'))
          .accessibilityLevel('no')
        Text($$.label)
          .fontSize($r('app.float.font_caption'))
          .maxFontScale(1.4)
          .fontWeight(this.activeRoute === $$.route ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeRoute === $$.route ? $r('app.color.brand_primary') : $r('app.color.text_primary'))
          .maxLines(1)
      }
      .padding({ top: 7, bottom: 7 })
      .width('100%')
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 56 })
    .backgroundColor(this.pressedRoute === $$.route ? $r('app.color.dock_pressed') : Color.Transparent)
    .borderRadius(28)
    .scale({ x: this.pressedRoute === $$.route && !this.reduceAnimation ? 0.96 : 1,
      y: this.pressedRoute === $$.route && !this.reduceAnimation ? 0.96 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.25, 0.88))
    .padding(0)
    .stateEffect(false)
    .accessibilityText($$.label)
    .accessibilitySelected(this.activeRoute === $$.route)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedRoute = $$.route;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedRoute = '';
      }
    })
    .onClick(() => {
      if (this.activeRoute !== $$.route) {
        this.onTabSelected($$.route);
      }
    })
  }

  @Builder
  private addButton() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.dock_add'))
          .width(28)
          .height(28)
          .fillColor($r('app.color.dock_on_action'))
          .accessibilityLevel('no')
      }
      .accessibilityText('新增物品')
      .linearGradient({ angle: 90, colors: [[$r('app.color.dock_action_start'), 0],
        [$r('app.color.dock_action_end'), 1]] })
      .borderRadius(28)
      .width('90%')
      .constraintSize({ minWidth: 44, maxWidth: 64 })
      .height(48)
      .scale({ x: this.addPressed && !this.reduceAnimation ? 0.94 : 1,
        y: this.addPressed && !this.reduceAnimation ? 0.94 : 1 })
      .animation(uiSpring(this.reduceAnimation, 0.25, 0.88))
      .padding(0)
      .stateEffect(false)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.addPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.addPressed = false;
        }
      })
      .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM,
        params: { mode: 'create', returnTo: this.activeRoute } }))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
