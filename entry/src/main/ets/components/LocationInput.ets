@Component
export struct LocationInput {
  @Link locationPath: string;

  build() {
    Column({ space: 8 }) {
      Text('存放位置（可选）')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      TextInput({ text: this.locationPath, placeholder: '例如：厨房 / 冰箱 / 冷藏层' })
        .maxLength(200)
        .onChange((value: string) => this.locationPath = value)
        .onSubmit(() => this.locationPath = this.locationPath.trim())
    }
    .alignItems(HorizontalAlign.Start)
  }
}
