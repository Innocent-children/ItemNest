import { localImageSource } from '../ui/ImageSource';
import { ItemHeroMotion } from '../ui/ItemHeroMotion';
import { uiSpring, uiReveal, numericMotion } from '../ui/VisualStyle';
import { ItemSummary } from '../model/Item';
import { ExpiryStatusTag } from './ExpiryStatusTag';
import { expiryStatusLabel, ExpiryStatus } from '../model/ExpiryStatus';
import { activeLocationText } from '../service/ItemFlowPresentation';

@Component
export struct ItemCard {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop heroKey: string = 'collection';
  @StorageLink('itemtrace.heroSourceKey') private heroSourceKey: string = '';
  @Prop @Watch('onItemChanged') item: ItemSummary;
  @State private photoFailed: boolean = false;
  @State private pressed: boolean = false;

  private thumbnailKey(): string {
    return `item-photo:${this.heroKey}:${this.item.id}`;
  }

  private onItemChanged(): void {
    this.photoFailed = false;
  }

  private locationText(): string {
    return activeLocationText(this.item.activeLocationPaths, this.item.locationPath, this.item.quantity);
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Stack() {
          if (this.item.photoPath !== undefined && !this.photoFailed) {
            Image(localImageSource(this.item.photoPath)).width('100%').height('100%').objectFit(ImageFit.Cover)
              .onError(() => this.photoFailed = true).accessibilityLevel('no')
          } else {
            Image($r('app.media.ui_box')).width(26).height(26)
              .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
          }
        }
        .id(this.thumbnailKey()).opacity(this.heroSourceKey === this.thumbnailKey() ? 0 : 1)
        .width(52).height(60).borderRadius(14).clip(true).backgroundColor($r('app.color.surface_input'))
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
          Text(this.item.quantity.toString()).contentTransition(numericMotion(this.reduceAnimation, this.item.quantity)).fontSize(24).fontWeight(FontWeight.Medium)
            .fontColor(this.item.quantity === 0 ? $r('app.color.status_danger') : $r('app.color.text_primary'))
          Text(this.item.unit).fontSize(11).fontColor($r('app.color.text_secondary'))
        }.constraintSize({ maxWidth: 96 }).alignItems(HorizontalAlign.End)
      }.width('100%')
    }
    .width('100%').padding(18).borderRadius($r('app.float.radius_card'))
    .backgroundColor(this.pressed ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
    .accessibilityText(`${this.item.name}，${this.locationText()}，总量${this.item.quantity}${this.item.unit}，${expiryStatusLabel(this.item.expiryStatus)}，查看详情`)
    .scale({ x: this.pressed && !this.reduceAnimation ? 0.97 : 1, y: this.pressed && !this.reduceAnimation ? 0.97 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.36, 0.56))
    .onTouch((event: TouchEvent) => { this.pressed = event.type === TouchType.Down; })
    .transition(uiReveal(this.reduceAnimation))
    .onClick(() => {
      this.pressed = false;
      ItemHeroMotion.open(this.getUIContext(), this.item, this.thumbnailKey(), this.reduceAnimation);
    })
  }
}
