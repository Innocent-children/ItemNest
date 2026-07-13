@Component
export struct DeleteConfirmDialog {
  @Link visible: boolean;
  @Link confirmed: boolean;
  @Prop title: string = '确认删除物品？';
  @Prop description: string = '删除后不可恢复。';
  @Prop confirmText: string = '确认删除';

  build() {
    if (this.visible) {
      Column() {
        Column({ space: $r('app.float.space_4') }) {
          Text(this.title)
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.description)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
          Row({ space: $r('app.float.space_3') }) {
            Button('取消')
              .layoutWeight(1)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => {
                this.visible = false;
              })
            Button(this.confirmText)
              .layoutWeight(1)
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.status_danger'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => {
                this.visible = false;
                this.confirmed = true;
              })
          }
        }
        .width('88%')
        .constraintSize({ maxWidth: 480 })
        .padding($r('app.float.space_6'))
        .borderRadius($r('app.float.radius_card'))
        .backgroundColor($r('app.color.surface_card'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 200, curve: Curve.EaseOut }))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#66000000')
      .transition(TransitionEffect.opacity(0).animation({ duration: 180, curve: Curve.EaseOut }))
    }
  }
}
