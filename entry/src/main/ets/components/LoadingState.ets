import { uiSpring } from '../ui/VisualStyle';
@Component
export struct LoadingState {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @Prop text: string = '正在加载…';

  build() {
    Column({ space: 10 }) {
      LoadingProgress()
        .color($r('app.color.brand_primary'))
        .width(36).height(36)
      Text(this.text)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 6 }))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68)))
  }
}
