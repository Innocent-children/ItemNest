import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';

@Component
export struct OptionalDateField {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @Link value: string;
  @Prop editable: boolean = true;

  build() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Image($r('app.media.ui_clock')).width(20).height(20)
            .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
          Text(this.value.length > 0 ? this.value : '设置到期日期')
            .fontSize(16).fontColor(this.value.length > 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
            .layoutWeight(1).textAlign(TextAlign.Start)
          Image($r('app.media.ui_chevron')).width(14).height(14)
            .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
        }.width('100%')
      }
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .layoutWeight(1).height(52).padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.surface_input')).enabled(this.editable)
      .accessibilityText(this.value.length > 0 ? `到期日期 ${this.value}，点击修改` : '尚未设置到期日期，点击选择')
      .onClick(() => this.chooseDate())
      if (this.editable && this.value.length > 0) {
        Button('清除').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .fontSize(13).fontColor($r('app.color.text_secondary')).backgroundColor(Color.Transparent)
          .onClick(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => this.value = ''))
      }
    }.width('100%')
  }

  private chooseDate(): void {
    const parts = this.value.split('-');
    const selected = parts.length === 3 ? new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) : new Date();
    this.getUIContext().showDatePickerDialog({
      selected: selected,
      selectedTextStyle: { color: $r('app.color.brand_primary') },
      acceptButtonStyle: { fontColor: $r('app.color.brand_primary') },
      cancelButtonStyle: { fontColor: $r('app.color.text_secondary') },
      onDateAccept: (date: Date) => {
        const value = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => this.value = value);
      }
    });
  }
}
