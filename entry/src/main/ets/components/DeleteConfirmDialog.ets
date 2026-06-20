@Component
export struct DeleteConfirmDialog {
  @Link visible: boolean;
  @Link confirmed: boolean;

  build() {
    if (this.visible) {
      Column() {
        Column({ space: $r('app.float.space_4') }) {
          Text('确认删除物品？')
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('第一阶段删除后不可恢复。')
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
            Button('确认删除')
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
        .padding($r('app.float.space_6'))
        .borderRadius($r('app.float.radius_card'))
        .backgroundColor($r('app.color.surface_card'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#66000000')
    }
  }
}
