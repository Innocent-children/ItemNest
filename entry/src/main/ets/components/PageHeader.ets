import { NavigationHelper } from '../navigation/NavigationHelper';
import { MaterialButtonStyle, uiSpring } from '../ui/VisualStyle';

@Component
export struct PageHeader {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop largeTitle: boolean = false;
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
        .attributeModifier(new MaterialButtonStyle(this.reduceAnimation))
        .width(44).height(44).padding(0).borderRadius(22)

        .borderRadius(22)
        .accessibilityText('返回上一页')
        .enabled(this.actionEnabled)
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onClick(() => this.onBack())
      }
      Column({ space: 6 }) {
        if (this.eyebrow.length > 0) {
          Text(this.eyebrow).fontSize(11).letterSpacing(2)
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))
        }
        Text(this.title)
          .fontSize(this.largeTitle ? 30 : 21).animation(uiSpring(this.reduceAnimation, 0.35, 0.82)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(11).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
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
        .attributeModifier(new MaterialButtonStyle(this.reduceAnimation))
        .padding({ left: 14, right: 14 }).height(44)
        .borderRadius(22)

        .borderRadius(22)
        .accessibilityText(this.actionText)
        .enabled(this.actionEnabled).animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onClick(() => this.onAction())
      }
    }
    .width('100%').constraintSize({ maxWidth: 960 })
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .height('100%')
  }
}
