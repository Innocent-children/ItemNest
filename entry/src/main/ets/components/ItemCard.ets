import { uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { ItemSummary } from '../model/Item';
import { RouteName } from '../navigation/RouteName';
import { ExpiryStatusTag } from './ExpiryStatusTag';
import { expiryStatusLabel } from '../model/ExpiryStatus';
import { activeLocationText } from '../service/ItemFlowPresentation';

@Component
export struct ItemCard {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop item: ItemSummary;
  @State private pressed: boolean = false;

  private locationText(): string {
    return activeLocationText(this.item.activeLocationPaths, this.item.locationPath, this.item.quantity);
  }

  build() {
    Row({ space: $r('app.float.space_3') }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.item.name.substring(0, 1))
          .fontSize($r('app.float.font_section'))
          .maxFontScale(1.4)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
      }
      .width(52)
      .height(52)
      .borderRadius(19)
      .linearGradient({ angle: 135, colors: [[$r('app.color.surface_accent'), 0], [$r('app.color.surface_card'), 1]] })
      .accessibilityLevel('no')
      Column({ space: $r('app.float.space_1') }) {
        Row({ space: $r('app.float.space_2') }) {
          Text(this.item.name)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          ExpiryStatusTag({ status: this.item.expiryStatus })
        }
        Text(this.locationText())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        Row({ space: $r('app.float.space_2') }) {
          Text(`总量 ${this.item.quantity}${this.item.unit}`)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
          if (this.item.category !== undefined) {
            Text('·')
              .fontColor($r('app.color.text_secondary'))
          }
          if (this.item.category !== undefined) {
            Text(this.item.category)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
      }
      .layoutWeight(1)
      Image($r('app.media.ui_chevron'))
        .width(15).height(15)
        .fillColor($r('app.color.text_secondary'))
        .accessibilityLevel('no')
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor(this.pressed ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
    .border({ width: 0.5, color: $r('app.color.border_subtle') })
    .shadow({ radius: 8, color: $r('app.color.shadow_soft'), offsetY: 4 })
    .accessibilityText(`${this.item.name}，${this.item.quantity}${this.item.unit}，${expiryStatusLabel(this.item.expiryStatus)}，查看详情`)
    .scale({ x: this.pressed && !this.reduceAnimation ? 0.975 : 1, y: this.pressed && !this.reduceAnimation ? 0.975 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
    .transition(TransitionEffect.OPACITY
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: this.item.id } }))
  }
}
