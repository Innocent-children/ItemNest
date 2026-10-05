import { uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { ItemSummary } from '../model/Item';
import { RouteName } from '../navigation/RouteName';
import { ExpiryStatusTag } from './ExpiryStatusTag';
import { expiryStatusLabel, ExpiryStatus } from '../model/ExpiryStatus';
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
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Stack() {
          Image($r('app.media.ui_box')).width(26).height(26)
            .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
        }
        .width(52).height(60).borderRadius(14).backgroundColor($r('app.color.surface_input'))
        Column({ space: 7 }) {
          Text(this.item.name).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary')).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Row({ space: 4 }) {
            Image($r('app.media.ui_location')).width(12).height(12)
              .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
            Text(this.locationText()).fontSize(12).fontColor($r('app.color.text_secondary'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }.width('100%')
          if (this.item.expiryStatus === ExpiryStatus.EXPIRED || this.item.expiryStatus === ExpiryStatus.DUE_SOON) {
            ExpiryStatusTag({ status: this.item.expiryStatus })
          } else if (this.item.category !== undefined) {
            Text(this.item.category).fontSize(11).fontColor($r('app.color.text_tertiary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text(this.item.quantity.toString()).fontSize(24).fontWeight(FontWeight.Medium)
            .fontColor(this.item.quantity === 0 ? $r('app.color.status_danger') : $r('app.color.text_primary'))
          Text(this.item.unit).fontSize(11).fontColor($r('app.color.text_secondary'))
        }.constraintSize({ maxWidth: 96 }).alignItems(HorizontalAlign.End)
      }.width('100%')
    }
    .width('100%').padding(18).borderRadius($r('app.float.radius_card'))
    .backgroundColor(this.pressed ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
    .accessibilityText(`${this.item.name}，${this.locationText()}，总量${this.item.quantity}${this.item.unit}，${expiryStatusLabel(this.item.expiryStatus)}，查看详情`)
    .scale({ x: this.pressed && !this.reduceAnimation ? 0.985 : 1, y: this.pressed && !this.reduceAnimation ? 0.985 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.3, 0.82))
    .onTouch((event: TouchEvent) => { this.pressed = event.type === TouchType.Down; })
    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: this.item.id } }))
  }
}
