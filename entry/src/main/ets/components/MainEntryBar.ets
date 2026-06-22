import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';

@Component
export struct MainEntryBar {
  @Prop activeRoute: string = RouteName.HOME;

  build() {
    Row({ space: $r('app.float.space_2') }) {
      this.navButton('首页', RouteName.HOME)
      this.navButton('物品', RouteName.ITEM_LIST)
      this.addButton()
      this.navButton('搜索', RouteName.SEARCH)
      this.navButton('设置', RouteName.SETTINGS)
    }
    .width('100%')
    .padding({ left: $r('app.float.space_3'), right: $r('app.float.space_3'), top: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: { top: 1 }, color: $r('app.color.border_subtle') })
  }

  @Builder
  private navButton(label: string, route: string) {
    Button(label)
      .layoutWeight(1)
      .fontSize($r('app.float.font_caption'))
      .fontColor(this.activeRoute === route ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
      .backgroundColor(this.activeRoute === route ? $r('app.color.brand_primary') : $r('app.color.surface_app'))
      .border({ width: this.activeRoute === route ? 0 : 1, color: $r('app.color.border_subtle') })
      .borderRadius($r('app.float.radius_control'))
      .enabled(this.activeRoute !== route)
      .onClick(() => NavigationHelper.replaceUrl({ url: route }))
  }

  @Builder
  private addButton() {
    Button('+')
      .fontSize($r('app.float.font_section'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.brand_on_primary'))
      .backgroundColor($r('app.color.brand_primary'))
      .borderRadius(24)
      .width(48)
      .height(40)
      .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } }))
  }
}
