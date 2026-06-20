@Component
export struct ErrorState {
  @Prop message: string = '操作失败，请重试';

  build() {
    Column({ space: 10 }) {
      Text(this.message)
        .fontSize(16)
        .fontColor('#B42318')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
  }
}
