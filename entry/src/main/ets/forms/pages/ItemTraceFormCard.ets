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
        Text('ItemTrace')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
        Row({ space: 12 }) {
          this.countBlock(this.dueSoonCount, '即将到期')
          this.countBlock(this.todayReminderCount, '今日提醒')
        }
        Text('点击打开应用，快速记录物品')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface_card'))
    }
  }

  @Builder
  private countBlock(count: string, label: string) {
    Column({ space: 2 }) {
      Text(count)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
  }
}
