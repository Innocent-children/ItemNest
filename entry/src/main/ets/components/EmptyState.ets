import { NavigationHelper } from '../navigation/NavigationHelper';

@Component
export struct EmptyState {
  @Prop title: string = '暂无物品';
  @Prop description: string = '';
  @Prop actionText: string = '';
  @Prop actionRoute: string = '';
  @Prop actionMode: string = '';
  @Prop actionReturnTo: string = '';

  build() {
    Column({ space: $r('app.float.space_2') }) {
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
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.openAction())
      }
    }
    .width('100%')
    .padding($r('app.float.space_6'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .alignItems(HorizontalAlign.Center)
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
