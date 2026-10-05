@Component
export struct InventoryMetrics {
  @Prop total: number = 0;
  @Prop available: number | undefined = undefined;
  @Prop borrowed: number | undefined = undefined;
  @Prop unit: string = '';

  build() {
    Row() {
      this.metric(this.total, '拥有总量')
      this.metric(this.available, '在手可用')
      this.metric(this.borrowed, '借出未还')
    }.width('100%')
  }

  @Builder
  private metric(value: number | undefined, label: string) {
    Column({ space: 6 }) {
      Row({ space: 3 }) {
        Text(value === undefined ? '—' : value.toString())
          .fontSize(26).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Text(this.unit).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
      }
      Text(label).fontSize(12).fontColor($r('app.color.text_secondary'))
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      .accessibilityGroup(true).accessibilityText(`${label}，${value === undefined ? '暂不可用' : value.toString() + this.unit}`)
  }
}
