import { uiSpring } from '../ui/VisualStyle';

@Component
export struct LocationInput {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @Link locationPath: string;

  build() {
    Column({ space: $r('app.float.space_2') }) {
      TextInput({ text: this.locationPath, placeholder: '例如：厨房 / 冰箱 / 冷藏层' })
        .borderWidth(1)
        .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'locationPath'))
        .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
          if (this.focusedField === 'locationPath') { this.focusedField = ''; }
        }))
        .maxLength(200)
        .height(52)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius($r('app.float.radius_control'))
        .accessibilityText('默认存放位置，可选')
        .borderColor(this.focusedField === 'locationPath' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onChange((value: string) => this.locationPath = value)
        .onSubmit(() => this.locationPath = this.locationPath.trim())
    }
    .alignItems(HorizontalAlign.Start)
  }
}
