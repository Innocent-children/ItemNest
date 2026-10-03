@Component
export struct LoadingState {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop text: string = '正在加载…';

  build() {
    Column({ space: 10 }) {
      LoadingProgress()
        .color($r('app.color.brand_primary'))
      Text(this.text)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 6 }))
      .animation({ duration: this.reduceAnimation ? 0 : 180, curve: Curve.EaseOut }))
  }
}
