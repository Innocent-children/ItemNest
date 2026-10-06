class ItemTraceFormLinkParams {
  source: string = 'itemtrace-form';
  action: string;

  constructor(action: string) {
    this.action = action;
  }
}

@Entry
@Component
struct ItemTraceFormCard {
  @State dueSoonCount: string = '—';
  @State todayReminderCount: string = '—';

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.app_name')).letterSpacing(2).fontSize(12)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.hero_text'))
      Row({ space: 12 }) {
        this.countLink(this.dueSoonCount, '到期待处理', 'expiry')
        this.countLink(this.todayReminderCount, '今日提醒', 'reminders')
      }.width('100%')
      FormLink({ action: 'router', abilityName: 'EntryAbility', params: new ItemTraceFormLinkParams('add') }) {
        Text('+ 记录一件物品').fontSize(13).fontColor($r('app.color.hero_secondary'))
          .width('100%').padding({ top: 8, bottom: 8 })
      }.width('100%')
    }.width('100%').height('100%').padding(20).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.hero_start'))
  }

  @Builder
  private countLink(count: string, label: string, action: string) {
    FormLink({ action: 'router', abilityName: 'EntryAbility', params: new ItemTraceFormLinkParams(action) }) {
      Column({ space: 2 }) {
        Text(count).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.hero_text'))
        Text(label).fontSize(12).fontColor($r('app.color.hero_secondary'))
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 4, bottom: 4 })
    }.layoutWeight(1)
  }
}
