import { Location, normalize } from '../model/Models';
import { Repository } from '../data/Repository';
import { ActionButton } from './Common';

@Component
export struct LocationPicker {
  repository: Repository = new Repository();
  selected: string = '';
  onChoose: (id: string) => void = () => {};
  onCancel: () => void = () => {};
  @State parent: string = '';
  @State query: string = '';
  @State name: string = '';
  @State error: string = '';
  @State locations: Location[] = [];
  aboutToAppear(): void { this.locations = this.repository.data.locations; }
  private ancestors(): Location[] {
    const result: Location[] = []; let id = this.parent;
    while (id) { const node = this.locations.find((value: Location) => value.id === id); if (!node) break; result.unshift(node); id = node.parentId; }
    return result;
  }
  private createLocation(): void {
    try {
      const existing = this.locations.find((node: Location) => node.parentId === this.parent && normalize(node.name) === normalize(this.name));
      if (existing) { this.error = '这里已有这个位置，可在上方选择，或修改名称'; return; }
      const node = new Location(); node.name = this.name; node.parentId = this.parent;
      this.onChoose(this.repository.saveLocation(node));
    } catch (error) { this.error = (error as Error).message; }
  }
  build() {
    Column({ space: 12 }) {
      Text('放在哪里').fontSize(22).fontColor($r('app.color.text')).accessibilityLevel('yes')
      if (this.selected) { Text('当前：' + this.repository.path(this.selected)).fontColor($r('app.color.secondary')) }
      if (this.locations.length) { TextInput({ text: this.query, placeholder: '搜索位置名称或完整路径' }).onChange((value: string) => this.query = value) }
      if (!this.query && !this.parent && this.repository.data.preference.recentLocations.length) {
        Text('最近使用').fontColor($r('app.color.secondary'))
        ForEach(this.repository.data.preference.recentLocations.filter((id: string) => this.locations.some((node: Location) => node.id === id)), (id: string) => {
          ActionButton({ label: this.repository.path(id), run: () => this.onChoose(id) })
        })
      }
      if (!this.query && this.parent) {
        ActionButton({ label: '全部位置', run: () => this.parent = '' })
        ForEach(this.ancestors(), (node: Location) => { ActionButton({ label: node.name, run: () => this.parent = node.id }) }, (node: Location) => node.id)
      }
      ForEach(this.locations.filter((node: Location) => this.query ? normalize(this.repository.path(node.id)).includes(normalize(this.query)) : node.parentId === this.parent).sort((a: Location, b: Location) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name) || a.id.localeCompare(b.id)), (node: Location) => {
        Column({ space: 6 }) {
          Text(this.query ? this.repository.path(node.id) : node.name).fontColor($r('app.color.text')).width('100%')
          Row({ space: 8 }) {
            ActionButton({ label: this.selected === node.id ? '✓ 选择这里' : '选择这里', run: () => this.onChoose(node.id) })
            if (this.locations.some((child: Location) => child.parentId === node.id)) { ActionButton({ label: '查看子位置', run: () => { this.parent = node.id; this.query = ''; } }) }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor($r('app.color.surface')).borderRadius(16)
      }, (node: Location) => node.id)
      Text(this.parent ? '在“' + this.repository.path(this.parent) + '”里面新建' : this.locations.length ? '记一个新位置' : '从一个抽屉、一层架子开始').fontColor($r('app.color.secondary'))
      if (this.ancestors().length >= 4) { Text('已到第四层，请先选择上层再新建').fontColor($r('app.color.warning')) }
      else {
        TextInput({ text: this.name, placeholder: '例如：书桌抽屉' }).maxLength(30).onChange((value: string) => { this.name = value; this.error = ''; })
        ActionButton({ label: '新建并选择', primary: true, run: () => this.createLocation() })
      }
      if (this.error) { Text(this.error).fontColor($r('app.color.danger')) }
      ActionButton({ label: '稍后补充位置', run: () => this.onChoose('') })
      ActionButton({ label: '返回记录', run: () => this.onCancel() })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
