import { CardLine } from './CardContent';

@Component
export struct NestCard {
  @LocalStorageProp('wide') wide: boolean = false;
  @LocalStorageProp('mode') mode: string = 'QUICK';
  @LocalStorageProp('summary') summary: boolean = false;
  @LocalStorageProp('lines') lines: CardLine[] = [];
  @LocalStorageProp('updated') updated: string = '';

  private open(action: string, itemId: string = ''): void {
    postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { action: action, itemId: itemId } });
  }

  @Builder
  actionRow(label: string, icon: Resource, action: string, primary: boolean) {
    Row({ space: 8 }) {
      Image(icon).width(18).height(18)
      Text(label).fontSize(14).minFontSize(11).maxFontSize(14).maxLines(1)
        .fontWeight(FontWeight.Medium).fontColor(primary ? $r('app.color.onPrimary') : $r('app.color.text')).layoutWeight(1)
    }.width('100%').layoutWeight(1).padding({ left: 12, right: 10 }).borderRadius(14)
    .backgroundColor(primary ? $r('app.color.primary') : $r('app.color.subtle'))
    .onClick(() => this.open(action)).accessibilityText(label)
  }

  @Builder
  header(title: string) {
    Row() {
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
        .maxLines(1).minFontSize(12).maxFontSize(15).layoutWeight(1)
      if (this.wide) {
        Text(this.updated ? this.updated + ' 更新' : '我的家当').fontSize(10).fontColor($r('app.color.secondary')).maxLines(1)
      } else {
        Image($r('app.media.card_nest')).width(18).height(18)
      }
    }.width('100%').height(24)
  }

  @Builder
  itemLine(line: CardLine) {
    if (this.wide) {
      Row({ space: 8 }) {
        Text(line.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text(line.detail).fontSize(11).fontColor(line.urgent ? $r('app.color.danger') : $r('app.color.secondary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).textAlign(TextAlign.End)
      }.width('100%').layoutWeight(1)
      .onClick(() => this.open('item', line.id)).accessibilityText(line.title + '，' + line.detail)
    } else {
      Column({ space: 5 }) {
        Text(line.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(line.detail).fontSize(11).fontColor(line.urgent ? $r('app.color.danger') : $r('app.color.secondary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      .onClick(() => this.open('item', line.id)).accessibilityText(line.title + '，' + line.detail)
    }
  }

  @Builder
  emptyContent() {
    Column({ space: 5 }) {
      Image(this.mode === 'DATES' ? $r('app.media.card_clock') : $r('app.media.card_nest'))
        .width(22).height(22)
      Text(!this.summary ? '详情由你决定' : this.mode === 'DATES' ? '暂无待办日期' : '常用物品，抬眼可见')
        .fontSize(13).minFontSize(11).maxFontSize(13).fontColor($r('app.color.text')).maxLines(1)
      Text(!this.summary ? '点击设置桌面摘要' : this.mode === 'DATES' ? '记下日期，在这里关注' : '点击选择常用物品')
        .fontSize(10).fontColor($r('app.color.secondary')).maxLines(2).textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    .onClick(() => this.open(!this.summary || this.mode === 'COMMON' ? 'cardSettings' : 'dates'))
  }

  build() {
    Column({ space: 10 }) {
      this.header(this.mode === 'QUICK' ? '随手记' : this.mode === 'DATES' ? '日期关注' : '常用位置')
      if (this.mode === 'QUICK') {
        Column({ space: 8 }) {
          this.actionRow('找东西', $r('app.media.card_search'), 'search', false)
          this.actionRow('记一件', $r('app.media.card_add'), 'capture', true)
        }.width('100%').layoutWeight(1)
      } else if (this.wide) {
        Row({ space: 12 }) {
          Column() {
            if (this.lines.length) {
              ForEach(this.lines, (line: CardLine) => { this.itemLine(line) }, (line: CardLine) => line.key)
            } else {
              this.emptyContent()
            }
          }.layoutWeight(1).height('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 8 }) {
            this.actionRow(this.mode === 'DATES' ? '全部' : '查找', this.mode === 'DATES' ? $r('app.media.card_clock') : $r('app.media.card_search'), this.mode === 'DATES' ? 'dates' : 'search', false)
            this.actionRow('记录', $r('app.media.card_add'), 'capture', true)
          }.width(90).height('100%')
        }.width('100%').layoutWeight(1)
      } else {
        Column() {
          if (this.lines.length) {
            this.itemLine(this.lines[0])
          } else {
            this.emptyContent()
          }
        }.width('100%').layoutWeight(1)
        Row({ space: 6 }) {
          Text('查看日期').fontSize(12).minFontSize(10).maxFontSize(12).maxLines(1).fontColor($r('app.color.primary')).layoutWeight(1)
          Text('›').fontSize(16).fontColor($r('app.color.primary'))
        }.width('100%').height(30).padding({ left: 10, right: 10 }).borderRadius(10)
        .backgroundColor($r('app.color.subtle')).onClick(() => this.open('dates'))
      }
    }.padding(14).width('100%').height('100%').backgroundColor($r('app.color.surface'))
  }
}
