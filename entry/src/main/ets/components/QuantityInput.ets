import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';
import { ITEM_UNIT_OPTIONS, ItemUnit } from '../model/Item';

@Component
export struct QuantityInput {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @Link quantityText: string;
  @Link unit: ItemUnit;
  @Link errorMessage: string;
  @Prop inputEnabled: boolean = true;

  build() {
    Column({ space: 12 }) {
      Text('拥有多少？').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
      Row({ space: 8 }) {
        Button('−').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width(44).height(48).fontSize(22).fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent')).accessibilityText('数量减少一')
          .enabled(this.inputEnabled && Number(this.quantityText) > 0).animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => this.adjustQuantity(-1))
        TextInput({ text: this.quantityText, placeholder: '1' })
          .borderWidth(1)
          .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'quantityText'))
          .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
            if (this.focusedField === 'quantityText') { this.focusedField = ''; }
          }))
          .type(InputType.NUMBER_DECIMAL).height(48).layoutWeight(1).fontSize(20).textAlign(TextAlign.Center)
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_input')).borderRadius(14)
          .enabled(this.inputEnabled).accessibilityText('物品总数量')
          .borderColor(this.focusedField === 'quantityText' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onChange((value: string) => { this.quantityText = value; this.errorMessage = this.validateQuantity(value); })
        Button('+').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width(44).height(48).fontSize(22).fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent')).accessibilityText('数量增加一')
          .enabled(this.inputEnabled).animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => this.adjustQuantity(1))
        Select(ITEM_UNIT_OPTIONS.map((unit: ItemUnit): SelectOption => { return { value: unit }; }))
          .selected(ITEM_UNIT_OPTIONS.indexOf(this.unit)).value(this.unit).font({ size: 14 })
          .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface_input'))
          .borderRadius(14).width(78).height(48).enabled(this.inputEnabled).accessibilityText('物品单位')
          .onSelect((index: number) => this.unit = ITEM_UNIT_OPTIONS[index])
      }.width('100%')
      Text('总量包含借出部分。').fontSize(11).fontColor($r('app.color.text_secondary'))
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(13).fontColor($r('app.color.status_danger'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private validateQuantity(value: string): string {
    if (value.trim().length === 0) {
      return '';
    }
    const quantity = Number(value);
    if (!Number.isFinite(quantity) || quantity < 0 || Math.round(quantity * 100) !== quantity * 100) {
      return '数量必须是最多两位小数的非负数';
    }
    return '';
  }

  private adjustQuantity(delta: number): void {
    const current = this.quantityText.trim().length === 0 ? 0 : Number(this.quantityText);
    if (!Number.isFinite(current)) {
      this.errorMessage = this.validateQuantity(this.quantityText);
      return;
    }
    const next = Math.max(0, Math.round((current + delta) * 100) / 100);
    this.setQuantity(next.toString());
  }

  private setQuantity(value: string): void {
    this.quantityText = value;
    this.errorMessage = this.validateQuantity(value);
  }
}
