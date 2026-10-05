import { numericMotion, uiSpring } from '../ui/VisualStyle';
interface InventoryMetricParams {
  value: number | undefined;
  label: string;
}

@Component
export struct InventoryMetrics {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop total: number = 0;
  @Prop available: number | undefined = undefined;
  @Prop borrowed: number | undefined = undefined;
  @Prop unit: string = '';

  build() {
    Row() {
      this.metric({ value: this.total, label: '拥有总量' })
      this.metric({ value: this.available, label: '在手可用' })
      this.metric({ value: this.borrowed, label: '借出未还' })
    }.width('100%')
  }

  @Builder
  private metric($$: InventoryMetricParams) {
    Column({ space: 6 }) {
      Row({ space: 3 }) {
        Text($$.value === undefined ? '—' : $$.value.toString())
          .contentTransition(numericMotion(this.reduceAnimation, $$.value))
          .animation(uiSpring(this.reduceAnimation, 0.38, 0.86))
          .fontSize(26).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Text(this.unit).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
      }
      Text($$.label).fontSize(12).fontColor($r('app.color.text_secondary'))
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      .accessibilityGroup(true).accessibilityText(`${$$.label}，${$$.value === undefined ? '暂不可用' : $$.value.toString() + this.unit}`)
  }
}
