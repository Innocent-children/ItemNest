import { FormEntry } from '../../model/FormSnapshot';

class FormTarget {
  source: string = 'itemnest-form';
  action: string;
  itemId: string;
  constructor(action: string, itemId: string = '') { this.action = action; this.itemId = itemId; }
}

let storage = new LocalStorage();

@Entry(storage)
@Component
struct ItemNestFormCard {
  @LocalStorageProp('ohos.extra.param.key.form_dimension') dimension: number = 2;
  @State expiryEntries: FormEntry[] = [];
  @State dueSoonCount: string = '—';
  @State updatedLabel: string = '';
  @State error: string = '';
  build() {
    Column({ space: 8 }) {
      FormLink({ action: 'router', abilityName: 'EntryAbility', params: new FormTarget('expiry') }) {
        Text('临期物品 · ' + this.dueSoonCount).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.hero_text'))
      }
      ForEach(this.expiryEntries.slice(0, this.dimension === 3 ? 2 : 1), (entry: FormEntry, index: number) => {
        FormLink({ action: 'router', abilityName: 'EntryAbility', params: new FormTarget('item', entry.itemId) }) {
          Column({ space: 4 }) {
            Text(entry.title).fontSize(15).fontColor($r('app.color.hero_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(entry.subtitle).fontSize(12).fontColor($r('app.color.hero_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
      }, (entry: FormEntry, index: number) => entry.itemId + ':' + index)
      if (this.expiryEntries.length === 0) {
        Text(this.error || (this.dueSoonCount === '—' ? '正在读取…' : '暂无临期物品'))
          .fontSize(13).fontColor($r('app.color.hero_secondary'))
      }
      Blank()
      Text(this.updatedLabel).fontSize(10).fontColor($r('app.color.hero_secondary'))
    }.width('100%').height('100%').padding(16).alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.hero_start'))
  }
}
