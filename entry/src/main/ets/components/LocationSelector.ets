import { RoundedButtonStyle, uiSpring } from '../ui/VisualStyle';
import { LocationRecord } from '../model/Location';

@Component
export struct LocationSelector {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @Link selectedPath: string;
  @Prop locations: LocationRecord[] = [];

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.locations, (location: LocationRecord) => {
        if (location.active) {
          Button(location.path)
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .type(ButtonType.Capsule)
            .fontColor(this.selectedPath === location.path ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
            .backgroundColor(this.selectedPath === location.path ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
            .fontSize($r('app.float.font_caption'))
            .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
            .onClick(() => this.selectedPath = this.selectedPath === location.path ? '' : location.path)
        }
      }, (location: LocationRecord) => location.id)
    }
  }
}
