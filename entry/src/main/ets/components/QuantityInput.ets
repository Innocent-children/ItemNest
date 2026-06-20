import { ITEM_UNIT_OPTIONS, ItemUnit } from '../model/Item';

@Component
export struct QuantityInput {
  @Link quantityText: string;
  @Link unit: ItemUnit;
  @Link errorMessage: string;

  build() {
    Column({ space: 8 }) {
      Text('数量与单位')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      TextInput({ text: this.quantityText, placeholder: '默认 1' })
        .type(InputType.Number)
        .onChange((value: string) => {
          this.quantityText = value;
          this.errorMessage = this.validateQuantity(value);
        })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(ITEM_UNIT_OPTIONS, (option: ItemUnit) => {
          Button(option)
            .type(this.unit === option ? ButtonType.Capsule : ButtonType.Normal)
            .fontSize(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => this.unit = option)
        }, (option: ItemUnit) => option)
      }
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#B42318')
      }
    }
    .alignItems(HorizontalAlign.Start)
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
}
