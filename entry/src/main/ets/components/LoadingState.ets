@Component
export struct LoadingState {
  @Prop text: string = '正在加载…';

  build() {
    Column({ space: 10 }) {
      LoadingProgress()
      Text(this.text)
        .fontSize(14)
        .fontColor('#6B7280')
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
  }
}
