import { router } from '@kit.ArkUI';
import { ItemSummary } from '../model/Item';
import { RouteName } from '../navigation/RouteName';
import { ExpiryStatusTag } from './ExpiryStatusTag';

@Component
export struct ItemCard {
  @Prop item: ItemSummary;

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.item.name)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.locationPath !== undefined) {
            Text(this.item.locationPath)
              .fontSize(14)
              .fontColor('#475467')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.item.category !== undefined) {
            Text(this.item.category)
              .fontSize(13)
              .fontColor('#667085')
          }
        }
        .layoutWeight(1)
        ExpiryStatusTag({ status: this.item.expiryStatus })
      }
      Row({ space: 8 }) {
        Text(`${this.item.quantity}${this.item.unit}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        if (this.item.expirationDate !== undefined) {
          Text(`到期：${this.item.expirationDate}`)
            .fontSize(13)
            .fontColor('#667085')
        }
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .onClick(() => router.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: this.item.id } }))
  }
}
