class QuickTarget {
  source: string = 'itemtrace-form';
  action: string;
  constructor(action: string) { this.action = action; }
}

@Entry
@Component
struct QuickFormCard {
  build() {
    Column({ space: 12 }) {
      Text('记住一件物品').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.hero_text'))
      this.entry('扫码录入', 'scan')
      this.entry('拍照识别', 'camera')
      this.entry('手动记录', 'add')
    }.width('100%').height('100%').padding(16).alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.hero_start'))
  }
  @Builder
  private entry(title: string, action: string) {
    FormLink({ action: 'router', abilityName: 'EntryAbility', params: new QuickTarget(action) }) {
      Text(title).fontSize(14).fontColor($r('app.color.hero_text')).width('100%').padding({ top: 4, bottom: 4 })
    }
  }
}
