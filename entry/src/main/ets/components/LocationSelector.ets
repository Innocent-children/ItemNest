import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';

@Component
export struct LocationSelector {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @Link selectedPath: string;
  @Prop paths: string[] = [];
  @Prop inputEnabled: boolean = true;

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.paths, (path: string) => {
        Button(path)
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .type(ButtonType.Capsule)
          .fontColor(this.selectedPath.trim() === path ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
          .backgroundColor(this.selectedPath.trim() === path ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
          .fontSize($r('app.float.font_caption'))
          .constraintSize({ minHeight: 44, maxWidth: '100%' })
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .enabled(this.inputEnabled)
          .accessibilityText(`${path}${this.selectedPath.trim() === path ? '，已选中' : '，点击填入位置'}`)
          .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
          .onClick(() => this.selectedPath = path)
      }, (path: string) => path)
    }
    .width('100%')
  }
}
