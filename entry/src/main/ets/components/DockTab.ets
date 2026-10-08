import { dockBarHeight } from '../ui/VisualStyle';

@Component
export struct DockTab {
  @Prop label: string = '';
  @Prop symbol: Resource = $r('sys.symbol.house');
  @Prop selected: boolean = false;
  @Prop index: number = 0;
  @Prop highlightPosition: number = 0;
  @Prop slotWidth: number = 68;
  @Prop reduceAnimation: boolean = false;
  onDockTouch: (event: TouchEvent) => void = (): void => {};
  onTabAreaChanged: (width: number, windowX: number) => void = (): void => {};

  private highlightOffset(): number {
    return 4 + (this.highlightPosition - this.index) * this.slotWidth;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 每个原生页签显示移动胶囊落在自己范围内的部分，跨页签时仍是一块连续背景。
      this.tabContent($r('app.color.text_secondary'), false)
      Stack({ alignContent: Alignment.TopStart }) {
        // 白色内容抵消胶囊的位移，绿色区域之外仍显示下层灰色内容。
        this.tabContent($r('app.color.brand_on_primary'), true)
      }
        .width(this.slotWidth - 8)
        .height(dockBarHeight - 8)
        .borderRadius(dockBarHeight / 2)
        .clip(true)
        .backgroundColor($r('app.color.brand_primary'))
        .translate({ x: this.highlightOffset() })
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no-hide-descendants')
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .accessibilityGroup(true)
    .accessibilityText(this.label)
    .accessibilitySelected(this.selected)
    .onTouch((event: TouchEvent) => this.onDockTouch(event))
    .onAreaChange((_old: Area, area: Area) =>
      this.onTabAreaChanged(Number(area.width), Number(area.globalPosition.x)))
  }

  @Builder
  private tabContent(color: Resource, insideHighlight: boolean) {
    Row() {
      Column({ space: 2 }) {
        SymbolGlyph(this.symbol)
          .fontSize(22)
          .fontColor([color])
          .symbolEffect(new BounceSymbolEffect(), this.selected && !this.reduceAnimation ? 1 : -1)
          .accessibilityLevel('no')
        Text(this.label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(color)
          .maxLines(1)
      }
      .width('100%')
      .height(dockBarHeight - 8)
      .justifyContent(FlexAlign.Center)
    }
    .width(this.slotWidth)
    .height(dockBarHeight - 8)
    .padding({ left: 4, right: 4 })
    .translate({ x: insideHighlight ? -this.highlightOffset() : 0 })
  }
}
