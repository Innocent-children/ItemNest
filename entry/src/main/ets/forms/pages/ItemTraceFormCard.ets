class QuickAddFormLinkParams {
  source: string = 'itemtrace-form-quick-add';
}

@Entry
@Component
struct ItemTraceFormCard {
  @State dueSoonCount: string = '—';
  @State todayReminderCount: string = '—';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: new QuickAddFormLinkParams()
    }) {
      Column({ space: 8 }) {
        Text('ITEMTRACE').letterSpacing(2)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.hero_text'))
        Row({ space: 12 }) {
          this.countBlock(this.dueSoonCount, '到期待处理')
          this.countBlock(this.todayReminderCount, '今日提醒')
        }
        Text('+ 记录一件物品')
          .fontSize(13)
          .fontColor($r('app.color.hero_secondary'))
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.hero_start'))
    }
  }

  @Builder
  private countBlock(count: string, label: string) {
    Column({ space: 2 }) {
      Text(count)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hero_text'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.hero_secondary'))
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start)
  }
}
