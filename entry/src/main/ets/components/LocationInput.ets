@Component
export struct LocationInput {
  @Link locationPath: string;

  build() {
    Column({ space: $r('app.float.space_2') }) {
      TextInput({ text: this.locationPath, placeholder: '例如：厨房 / 冰箱 / 冷藏层' })
        .maxLength(200)
        .height(52)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius($r('app.float.radius_control'))
        .accessibilityText('默认存放位置，可选')
        .onChange((value: string) => this.locationPath = value)
        .onSubmit(() => this.locationPath = this.locationPath.trim())
    }
    .alignItems(HorizontalAlign.Start)
  }
}
