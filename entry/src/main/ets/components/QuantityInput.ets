import { ITEM_UNIT_OPTIONS, ItemUnit } from '../model/Item';

@Component
export struct QuantityInput {
  @Link quantityText: string;
  @Link unit: ItemUnit;
  @Link errorMessage: string;
  @Prop inputEnabled: boolean = true;

  build() {
    Column({ space: $r('app.float.space_2') }) {
      Text('数量与单位')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.quantityText, placeholder: '默认 1' })
        .type(InputType.NUMBER_DECIMAL)
        .backgroundColor($r('app.color.surface_app'))
        .border({ width: 1, color: $r('app.color.border_subtle') })
        .borderRadius($r('app.float.radius_control'))
        .enabled(this.inputEnabled)
        .onChange((value: string) => {
          this.quantityText = value;
          this.errorMessage = this.validateQuantity(value);
        })
      Row({ space: $r('app.float.space_2') }) {
        Button('-')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(this.inputEnabled)
          .onClick(() => this.adjustQuantity(-1))
        Button('+')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .enabled(this.inputEnabled)
          .onClick(() => this.adjustQuantity(1))
        Button('置 0')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_app'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .enabled(this.inputEnabled)
          .onClick(() => this.setQuantity('0'))
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(ITEM_UNIT_OPTIONS, (option: ItemUnit) => {
          Button(option)
            .type(ButtonType.Capsule)
            .fontColor(this.unit === option ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
            .backgroundColor(this.unit === option ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
            .fontSize($r('app.float.font_caption'))
            .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
            .enabled(this.inputEnabled)
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
