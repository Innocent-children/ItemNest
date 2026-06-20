@Component
export struct DeleteConfirmDialog {
  @Link visible: boolean;
  @Link confirmed: boolean;

  build() {
    if (this.visible) {
      Column() {
        Column({ space: 16 }) {
          Text('确认删除物品？')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text('第一阶段删除后不可恢复。')
            .fontSize(15)
            .fontColor('#475467')
          Row({ space: 12 }) {
            Button('取消')
              .layoutWeight(1)
              .onClick(() => {
                this.visible = false;
              })
            Button('确认删除')
              .layoutWeight(1)
              .backgroundColor('#B42318')
              .onClick(() => {
                this.visible = false;
                this.confirmed = true;
              })
          }
        }
        .width('88%')
        .padding(24)
        .borderRadius(16)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#66000000')
    }
  }
}
