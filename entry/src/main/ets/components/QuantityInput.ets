import { ITEM_UNIT_OPTIONS, ItemUnit } from '../model/Item';

@Component
export struct QuantityInput {
  @Link quantityText: string;
  @Link unit: ItemUnit;
  @Link errorMessage: string;

  build() {
    Column({ space: $r('app.float.space_2') }) {
      Text('数量与单位')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.quantityText, placeholder: '默认 1' })
        .type(InputType.Number)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .onChange((value: string) => {
          this.quantityText = value;
          this.errorMessage = this.validateQuantity(value);
        })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(ITEM_UNIT_OPTIONS, (option: ItemUnit) => {
          Button(option)
            .type(ButtonType.Capsule)
            .fontColor(this.unit === option ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
            .backgroundColor(this.unit === option ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
            .fontSize($r('app.float.font_caption'))
            .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
            .onClick(() => this.unit = option)
        }, (option: ItemUnit) => option)
      }
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.status_danger'))
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
