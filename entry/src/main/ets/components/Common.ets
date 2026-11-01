// 公共界面组件。图标统一使用系统 HM Symbol，颜色取自应用色板，深浅色自动跟随。

@Component
export struct ActionButton {
  @Prop label: string = '';
  @Prop primary: boolean = false;
  @Prop tonal: boolean = false;
  @Prop danger: boolean = false;
  @Prop icon: Resource | undefined = undefined;
  run: () => void = () => {};

  private foreground(): ResourceColor {
    return this.primary ? $r('app.color.onPrimary') : this.danger ? $r('app.color.danger') : $r('app.color.primary');
  }

  build() {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: 6 }) {
        if (this.icon) {
          SymbolGlyph(this.icon).fontSize(18).fontColor([this.foreground()])
        }
        Text(this.label).fontSize(15).fontColor(this.foreground()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.padding({ left: this.icon ? 14 : 16, right: 16 })
    }
    .constraintSize({ minHeight: 44 })
    .backgroundColor(this.primary ? $r('app.color.primary') : this.danger && this.tonal ? $r('app.color.dangerSubtle') : this.tonal ? $r('app.color.subtle') : Color.Transparent)
    .accessibilityText(this.label)
    .onClick(() => this.run())
  }
}

@Component
export struct SectionHeading {
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Column({ space: 6 }) {
      Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
      if (this.subtitle) {
        Text(this.subtitle).fontSize(14).fontColor($r('app.color.secondary'))
      }
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 12, bottom: 12 })
  }
}

// 一行可点击的入口。plain 用于 GroupCard 内部：去掉自身底色，并在非首行上方画内缩分隔线。
@Component
export struct MenuRow {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop value: string = '';
  @Prop icon: Resource | undefined = undefined;
  @Prop plain: boolean = false;
  @Prop first: boolean = false;
  @Prop danger: boolean = false;
  @Prop chevron: boolean = true;
  action: () => void = () => {};

  build() {
    Column() {
      if (this.plain && !this.first) {
        Divider().strokeWidth(0.5).color($r('app.color.outline')).margin({ left: this.icon ? 56 : 16 })
      }
      Row({ space: 12 }) {
        if (this.icon) {
          SymbolGlyph(this.icon).fontSize(20)
            .fontColor([this.danger ? $r('app.color.danger') : $r('app.color.primary')])
            .width(28).height(28)
        }
        Column({ space: 4 }) {
          Text(this.title).fontSize(17).fontColor(this.danger ? $r('app.color.danger') : $r('app.color.text'))
          if (this.subtitle) {
            Text(this.subtitle).fontSize(13).fontColor($r('app.color.secondary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.value) {
          Text(this.value).fontSize(14).fontColor($r('app.color.secondary')).maxLines(1)
        }
        if (this.chevron) {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.tertiary')])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 14, top: this.plain ? 14 : 18, bottom: this.plain ? 14 : 18 })
      .constraintSize({ minHeight: this.plain ? 56 : 68 })
    }
    .width('100%')
    .backgroundColor(this.plain ? Color.Transparent : $r('app.color.surface'))
    .borderRadius(this.plain ? 0 : 20)
    .onClick(() => this.action())
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityText(this.title + (this.subtitle ? '，' + this.subtitle : '') + (this.value ? '，' + this.value : ''))
  }
}

// 把几行入口收进同一张卡片，减少首屏上互不相关的独立卡片。
@Component
export struct GroupCard {
  @Prop header: string = '';
  @BuilderParam content: () => void;

  build() {
    Column({ space: 6 }) {
      if (this.header) {
        Text(this.header).fontSize(14).fontColor($r('app.color.secondary')).padding({ left: 4 })
      }
      Column() {
        this.content()
      }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20).clip(true)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

// 图标在上、文字在下的快捷操作，用于详情页等需要一眼看到主要动作的地方。
@Component
export struct QuickAction {
  @Prop label: string = '';
  @Prop icon: Resource = $r('sys.symbol.plus');
  @Prop active: boolean = false;
  @Prop accent: boolean = false;
  run: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Stack() {
        SymbolGlyph(this.icon).fontSize(24)
          .fontColor([this.accent ? $r('app.color.onPrimary') : $r('app.color.primary')])
      }
      .width(52).height(52)
      .backgroundColor(this.accent ? $r('app.color.primary') : this.active ? $r('app.color.subtleStrong') : $r('app.color.subtle'))
      .borderRadius(18)
      Text(this.label).fontSize(13).fontColor($r('app.color.text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => this.run())
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityText(this.label)
  }
}

// 一个数字加一句口径说明。
@Component
export struct StatTile {
  @Prop value: string = '';
  @Prop label: string = '';

  build() {
    Column({ space: 2 }) {
      Text(this.value).fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
      Text(this.label).fontSize(12).fontColor($r('app.color.secondary')).maxLines(1)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true).accessibilityText(this.label + ' ' + this.value)
  }
}

// 两到三个互斥选项的分段选择。
@Component
export struct Segmented {
  @Prop options: string[] = [];
  @Prop selected: number = 0;
  onSelect: (index: number) => void = () => {};

  build() {
    Row() {
      ForEach(this.options, (option: string, index: number) => {
        Text(option).fontSize(15)
          .fontColor(this.selected === index ? $r('app.color.primary') : $r('app.color.secondary'))
          .fontWeight(this.selected === index ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center).layoutWeight(1).height(38)
          .backgroundColor(this.selected === index ? $r('app.color.surface') : Color.Transparent)
          .borderRadius(19)
          .shadow(this.selected === index ? { radius: 6, color: $r('app.color.shadow'), offsetY: 1 } : { radius: 0, color: Color.Transparent })
          .animation({ duration: 180, curve: Curve.FastOutSlowIn })
          .onClick(() => this.onSelect(index))
          .accessibilityText(option).accessibilitySelected(this.selected === index)
      }, (option: string) => option)
    }.width('100%').padding(3).backgroundColor($r('app.color.subtle')).borderRadius(22)
  }
}

// 小号状态标签。
@Component
export struct StatusTag {
  @Prop label: string = '';
  @Prop warning: boolean = false;

  build() {
    Text(this.label).fontSize(12)
      .fontColor(this.warning ? $r('app.color.warning') : $r('app.color.primary'))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(this.warning ? $r('app.color.warningSubtle') : $r('app.color.subtle'))
      .borderRadius(10)
  }
}
