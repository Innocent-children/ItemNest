import { NavigationHelper } from '../navigation/NavigationHelper';
import { RoundedButtonStyle } from '../ui/VisualStyle';

@Component
export struct PageHeader {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop eyebrow: string = '';
  @Prop showBack: boolean = false;
  @Prop actionText: string = '';
  @Prop actionIcon: Resource | undefined = undefined;
  @Prop actionEnabled: boolean = true;
  onBack: () => void = (): void => { NavigationHelper.back(); };
  onAction: () => void = (): void => {};

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.ui_back')).width(22).height(22)
            .fillColor($r('app.color.text_primary')).accessibilityLevel('no')
        }
        .width(44).height(44).padding(0).borderRadius(22)
        .backgroundColor($r('app.color.surface_card'))
        .accessibilityText('返回上一页')
        .enabled(this.actionEnabled)
        .onClick(() => this.onBack())
      }
      Column({ space: 6 }) {
        if (this.eyebrow.length > 0) {
          Text(this.eyebrow).fontSize(11).letterSpacing(2)
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))
        }
        Text(this.title)
          .fontSize(this.showBack ? 23 : $r('app.float.font_title'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.actionText.length > 0 || this.actionIcon !== undefined) {
        Button({ type: ButtonType.Normal }) {
          if (this.actionIcon !== undefined) {
            Image(this.actionIcon).width(22).height(22)
              .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
          } else {
            Text(this.actionText).fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_primary'))
          }
        }
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
        .padding({ left: 14, right: 14 }).height(44)
        .borderRadius(22).backgroundColor($r('app.color.surface_card'))
        .accessibilityText(this.actionText)
        .enabled(this.actionEnabled).onClick(() => this.onAction())
      }
    }
    .width('100%').constraintSize({ maxWidth: 960 })
    .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), top: 20, bottom: 20 })
  }
}
