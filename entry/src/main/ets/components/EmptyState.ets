import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';

@Component
export struct EmptyState {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop title: string = '暂无物品';
  @Prop description: string = '';
  @Prop actionText: string = '';
  @Prop actionRoute: string = '';
  @Prop actionMode: string = '';
  @Prop actionReturnTo: string = '';

  build() {
    Column({ space: $r('app.float.space_3') }) {
      Image($r('app.media.ui_collection')).width(160).height(128)
        .accessibilityLevel('no')
      Text(this.title)
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      if (this.actionText.length > 0 && this.actionRoute.length > 0) {
        Button(this.actionText)
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.openAction())
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 28, bottom: 28 })
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))

    .alignItems(HorizontalAlign.Center)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 8 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
  }

  private openAction(): void {
    if (this.actionMode.length > 0) {
      if (this.actionReturnTo.length > 0) {
        NavigationHelper.pushUrl({
          url: this.actionRoute,
          params: {
            mode: this.actionMode,
            returnTo: this.actionReturnTo
          }
        });
      } else {
        NavigationHelper.pushUrl({ url: this.actionRoute, params: { mode: this.actionMode } });
      }
      return;
    }
    NavigationHelper.pushUrl({ url: this.actionRoute });
  }
}
