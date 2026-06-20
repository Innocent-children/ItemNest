import { router } from '@kit.ArkUI';

@Component
export struct EmptyState {
  @Prop title: string = '暂无物品';
  @Prop description: string = '';
  @Prop actionText: string = '';
  @Prop actionRoute: string = '';

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
      }
      if (this.actionText.length > 0 && this.actionRoute.length > 0) {
        Button(this.actionText)
          .onClick(() => router.pushUrl({ url: this.actionRoute }))
      }
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
  }
}
