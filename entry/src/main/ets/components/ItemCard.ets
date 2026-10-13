import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { localImageSource } from '../ui/ImageSource';
import { hdsEffect } from '@kit.UIDesignKit';
import { SharedRouteMotion } from '../ui/SharedRouteMotion';
import { uiSpring, uiReveal, numericMotion } from '../ui/VisualStyle';
import { ItemSummary } from '../model/Item';
import { ExpiryStatusTag } from './ExpiryStatusTag';
import { ExpiryStatus } from '../model/ExpiryStatus';
import { activeLocationText, expiryDescription } from '../service/ItemFlowPresentation';

@Component
export struct ItemCard {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemnest.sharedItemSource') private sharedItemSource: string = '';
  @Prop heroKey: string = 'collection';
  @Prop detailSection: string = '';
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
    return activeLocationText(this.item.activeLocationPaths, this.item.locationPath, this.item.quantity,
      this.item.borrowedQuantity ?? 0);
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Stack() {
          if (this.sharedItemSource !== this.thumbnailKey()) {
            Stack() {
              if (this.item.photoPath !== undefined && !this.photoFailed) {
                Image(localImageSource(this.item.photoPath)).width('100%').height('100%').objectFit(ImageFit.Cover)
                  .onError(() => this.photoFailed = true).accessibilityLevel('no')
              } else {
                Image($r('app.media.ui_box')).width('46%').height('46%').objectFit(ImageFit.Contain)
                  .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
              }
            }.geometryTransition(this.reduceAnimation ? '' : this.thumbnailKey())
              .width(52).height(60).borderRadius(14).clip(true).backgroundColor($r('app.color.surface_accent'))
          }
        }.width(52).height(60).id(`frame:${this.thumbnailKey()}`)
        Column({ space: 7 }) {
          Text(this.item.name).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary')).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Row({ space: 4 }) {
            Image($r('app.media.ui_location')).width(12).height(12)
              .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
            Text(this.locationText()).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }.width('100%')
          if (this.item.expiryStatus === ExpiryStatus.EXPIRED || this.item.expiryStatus === ExpiryStatus.DUE_SOON) {
            ExpiryStatusTag({ status: this.item.expiryStatus, expirationDate: this.item.expirationDate ?? '' })
          } else if (this.item.category !== undefined) {
            Text(this.item.category).fontSize(11).fontColor($r('app.color.text_tertiary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.item.photoMatch) {
            Text('外观候选').fontSize(11).fontColor($r('app.color.brand_primary'))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text((this.item.availableQuantity ?? this.item.quantity).toString())
            .contentTransition(numericMotion(this.reduceAnimation, this.item.availableQuantity ?? this.item.quantity)).fontSize(24).fontWeight(FontWeight.Medium)
            .fontColor((this.item.availableQuantity ?? this.item.quantity) === 0 ? $r('app.color.status_danger') : $r('app.color.text_primary'))
          Text(this.item.unit).fontSize(11).fontColor($r('app.color.text_secondary'))
          Text(this.item.availableQuantity === undefined ? '拥有总量' : '在手可用').fontSize(11).fontColor($r('app.color.text_secondary'))
          if ((this.item.borrowedQuantity ?? 0) > 0) {
            Text(`借出 ${this.item.borrowedQuantity}${this.item.unit}`).fontSize(11).fontColor($r('app.color.text_secondary'))
          }
        }.constraintSize({ maxWidth: 96 }).alignItems(HorizontalAlign.End)
      }.width('100%')
    }
    .width('100%').padding(18).borderRadius($r('app.float.radius_card'))
    .clip(false)
    .stateEffect(false)
    .visualEffect(new hdsEffect.HdsEffectBuilder().pressShadow(hdsEffect.PressShadowType.BLEND_WHITE).buildEffect())
    .backgroundColor(this.pressed ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
    .accessibilityText(`${this.item.name}，${this.locationText()}，拥有总量${this.item.quantity}${this.item.unit}，${this.item.availableQuantity === undefined ? '' : `在手可用${this.item.availableQuantity}${this.item.unit}，借出${this.item.borrowedQuantity ?? 0}${this.item.unit}，`}${expiryDescription(this.item.expiryStatus, this.item.expirationDate ?? '')}，${this.item.photoMatch ? '外观候选，' : ''}查看详情`)
    .scale({ x: this.pressed && !this.reduceAnimation ? 0.97 : 1, y: this.pressed && !this.reduceAnimation ? 0.97 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.32, 0.82))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) { this.pressed = true; }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressed = false; }
    })
    .transition(uiReveal(this.reduceAnimation))
    .bindContextMenu(this.quickMenu, ResponseType.LongPress)
    .onClick(() => {
      this.pressed = false;
      if (this.detailSection.length > 0) {
        NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: this.item.id, section: this.detailSection } });
      } else {
        SharedRouteMotion.openItem(this.getUIContext(), this.item, this.thumbnailKey(), this.reduceAnimation);
      }
    })
  }

  @Builder
  private quickMenu() {
    Menu() {
      MenuItem({ content: `记录用掉 1${this.item.unit}` })
        .enabled((this.item.availableQuantity ?? this.item.quantity) >= 1)
        .onClick(() => this.openStockAction('consume-one'))
      MenuItem({ content: '记录其他用量' }).onClick(() => this.openStockAction('consume'))
      MenuItem({ content: '换位置' }).enabled(this.item.quantity > 0).onClick(() => this.openStockAction('move'))
      MenuItem({ content: '调整数量' }).onClick(() => this.openStockAction('adjust'))
    }
  }

  private openStockAction(section: string): void {
    this.pressed = false;
    NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL,
      params: { itemId: this.item.id, section: section, expectedUnit: this.item.unit } });
  }
}
