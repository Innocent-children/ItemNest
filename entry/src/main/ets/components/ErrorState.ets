@Component
export struct ErrorState {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
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
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 6 }))
      .animation({ duration: this.reduceAnimation ? 0 : 180, curve: Curve.EaseOut }))
  }
}
