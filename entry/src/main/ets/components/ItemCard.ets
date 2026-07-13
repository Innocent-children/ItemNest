import { NavigationHelper } from '../navigation/NavigationHelper';
import { ItemSummary } from '../model/Item';
import { RouteName } from '../navigation/RouteName';
import { ExpiryStatusTag } from './ExpiryStatusTag';

@Component
export struct ItemCard {
  @Prop item: ItemSummary;
  @State private pressed: boolean = false;

  build() {
    Row({ space: $r('app.float.space_3') }) {
      Text(this.item.name.substring(0, 1))
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.surface_accent'))
        .width(44)
        .height(44)
        .borderRadius(22)
        .textAlign(TextAlign.Center)
        .padding({ top: 10 })
      Column({ space: $r('app.float.space_1') }) {
        Row({ space: $r('app.float.space_2') }) {
          Text(this.item.name)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          ExpiryStatusTag({ status: this.item.expiryStatus })
        }
        if (this.item.locationPath !== undefined) {
          Text(this.item.locationPath)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Row({ space: $r('app.float.space_2') }) {
          Text(`${this.item.quantity}${this.item.unit}`)
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
      Text('>')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor(this.pressed ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.border_subtle') })
    .scale({ x: this.pressed ? 0.99 : 1, y: this.pressed ? 0.99 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
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
