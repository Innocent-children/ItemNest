import { uiSpring } from '../ui/VisualStyle';

/**
 * 页签内容由原生 TabBar 承载，背板材质和悬浮布局交给 Tabs。
 */
@Component
export struct MainDock {
  @Prop label: string = '';
  @Prop symbol: Resource;
  @Prop selected: boolean = false;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;

  build() {
    Column({ space: 3 }) {
      SymbolGlyph(this.symbol)
        .fontSize(24)
        .fontColor([this.selected ? $r('app.color.brand_primary') : $r('app.color.text_secondary')])
        .symbolEffect(new BounceSymbolEffect(), !this.reduceAnimation && this.selected ? 1 : -1)
        .accessibilityLevel('no')
      Text(this.label).fontSize(11).maxFontScale(1.4)
        .fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selected ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        .accessibilityLevel('no')
    }
    .opacity(this.keyboardVisible ? 0 : 1)
    .hitTestBehavior(this.keyboardVisible ? HitTestMode.None : HitTestMode.Default)
    .width('100%').height(56).padding(5).borderRadius(28)
    .backgroundColor(this.selected ? $r('app.color.dock_selected') : Color.Transparent)
    .scale({ x: this.selected && !this.reduceAnimation ? 1.04 : 1,
      y: this.selected && !this.reduceAnimation ? 1.04 : 1 })
    .animation(uiSpring(this.reduceAnimation, 0.3, 0.75))
    .accessibilityText(this.label).accessibilitySelected(this.selected)
  }
}
