@Component
export struct ErrorState {
  @Prop message: string = '操作失败，请重试';

  build() {
    Column({ space: $r('app.float.space_2') }) {
      Text(this.message)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.status_danger'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding($r('app.float.space_6'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.status_danger_soft'))
    .alignItems(HorizontalAlign.Center)
  }
}
