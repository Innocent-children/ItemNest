import { Location, normalize } from '../model/Models';
import { Repository } from '../data/Repository';
import { ActionButton } from './Common';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct LocationPicker {
  repository: Repository = new Repository();
  selected: string = '';
  title: string = '放在哪里';
  emptyLabel: string = '稍后补充位置';
  cancelLabel: string = '返回记录';
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
  private depth(id: string): number { let depth = 0; let current = id; while (current) { depth++; current = this.locations.find((node: Location) => node.id === current)?.parentId ?? ''; } return depth; }
  private children(id: string): number { return this.locations.filter((node: Location) => node.parentId === id).length; }
  private visible(): Location[] {
    return this.locations.filter((node: Location) => this.query ? normalize(this.repository.path(node.id)).includes(normalize(this.query)) : node.parentId === this.parent)
      .sort((a: Location, b: Location) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  }
  // 最近使用只补充当前列表里看不到的深层位置，避免同一个位置出现两次
  private recent(): string[] {
    const shown = this.visible().map((node: Location) => node.id);
    return this.repository.data.preference.recentLocations.filter((id: string) => this.locations.some((node: Location) => node.id === id) && !shown.includes(id)).slice(0, 4);
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
      Text(this.title).fontSize(22).fontColor($r('app.color.text')).accessibilityLevel('yes')
      if (this.selected) { Text('当前：' + this.repository.path(this.selected)).fontColor($r('app.color.secondary')) }
      if (this.locations.length > 6) { TextInput({ text: this.query, placeholder: '搜索位置名称或完整路径' }).onChange((value: string) => this.query = value) }
      if (!this.query && !this.parent && this.recent().length) {
        Text('最近使用').fontColor($r('app.color.secondary'))
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.recent(), (id: string) => { ActionButton({ label: this.repository.path(id), tonal: true, run: () => this.onChoose(id) }) }, (id: string) => id)
        }
      }
      if (!this.query && this.parent) {
        Scroll() {
          Row({ space: 4 }) {
            ActionButton({ label: '全部位置', run: () => this.parent = '' })
            ForEach(this.ancestors(), (node: Location) => { Text('/').fontColor($r('app.color.secondary')); ActionButton({ label: node.name, run: () => this.parent = node.id }) }, (node: Location) => node.id)
          }
        }.scrollable(ScrollDirection.Horizontal).width('100%')
        ActionButton({ label: '放在“' + this.repository.path(this.parent) + '”', tonal: true, run: () => this.onChoose(this.parent) })
      }
      ForEach(this.visible(), (node: Location) => {
        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text((this.selected === node.id ? '✓ ' : '') + (this.query ? this.repository.path(node.id) : node.name)).fontSize(17).fontColor($r('app.color.text')).width('100%')
            if (this.children(node.id)) { Text(`${this.children(node.id)} 个子位置`).fontSize(13).fontColor($r('app.color.secondary')) }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.depth(node.id) < 4) {
            Button('里面 ›').fontSize(14).height(36).fontColor($r('app.color.primary')).backgroundColor($r('app.color.subtle'))
              .accessibilityText('查看或新建' + node.name + '里面的位置')
              .onClick(() => { this.parent = node.id; this.query = ''; this.name = ''; this.error = ''; })
          }
        }.width('100%').padding({ left: 16, right: 12, top: 12, bottom: 12 }).constraintSize({ minHeight: 60 }).backgroundColor($r('app.color.surface')).borderRadius(16)
        .onClick(() => this.onChoose(node.id)).accessibilityText('选择' + this.repository.path(node.id))
      }, (node: Location) => node.id)
      Text(this.parent ? '在“' + this.repository.path(this.parent) + '”里面新建' : this.locations.length ? '记一个新位置' : '从一个抽屉、一层架子开始').fontColor($r('app.color.secondary'))
      if (this.ancestors().length >= 4) { Text('已到第四层，请先选择上层再新建').fontColor($r('app.color.warning')) }
      else {
        Row({ space: 8 }) {
          TextInput({ text: this.name, placeholder: this.parent ? '例如：第二层' : '例如：书桌抽屉' }).maxLength(30).layoutWeight(1).enterKeyType(EnterKeyType.Done)
            .onChange((value: string) => { this.name = value; this.error = ''; }).onSubmit(() => { if (this.name.trim()) this.createLocation(); })
          ActionButton({ label: '新建并选择', primary: true, run: () => { if (this.name.trim()) this.createLocation(); else this.error = '先写下位置名称'; } })
        }.width('100%')
      }
      if (this.error) { Text(this.error).fontColor($r('app.color.danger')) }
      Row({ space: 8 }) {
        ActionButton({ label: this.emptyLabel, run: () => this.onChoose('') })
        ActionButton({ label: this.cancelLabel, run: () => this.onCancel() })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
