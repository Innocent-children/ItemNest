@Component
export struct LocationInput {
  @Link locationPath: string;

  build() {
    Column({ space: $r('app.float.space_2') }) {
      Text('存放位置（可选）')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.locationPath, placeholder: '例如：厨房 / 冰箱 / 冷藏层' })
        .maxLength(200)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => this.locationPath = value)
        .onSubmit(() => this.locationPath = this.locationPath.trim())
    }
    .alignItems(HorizontalAlign.Start)
  }
}
