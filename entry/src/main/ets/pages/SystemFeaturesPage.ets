import { PageHeader } from '../components/PageHeader';
import { AppServices } from '../service/AppServices';
import { nativeTitleOptions } from '../ui/VisualStyle';
import { SystemFeatures } from '../model/SystemFeatures';

@Component
export struct SystemFeaturesPage {
  @StorageLink('itemtrace.safeAreaBottom') private bottom: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private assistant: boolean = false;
  @State private search: boolean = false;
  @State private location: boolean = false;
  @State private photo: boolean = true;
  @State private live: boolean = false;
  @State private ready: boolean = false;
  @State private busy: boolean = false;
  @State private message: string = '';

  aboutToAppear(): void { this.load(); }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          Text('选择物品信息可以在哪些系统入口使用。').fontSize(15).fontColor($r('app.color.text_secondary'))
          this.option('允许小艺查询与操作', '查询位置、库存和临期物品；修改操作在应用内确认。', this.assistant,
            (value: boolean) => { this.assistant = value; this.save(); })
          this.option('允许系统搜索物品', '通过系统意图查询当前物品并打开详情。', this.search,
            (value: boolean) => { this.search = value; this.save(); })
          this.option('搜索结果显示存放位置', '关闭后，系统搜索结果只展示物品名称。', this.location,
            (value: boolean) => { this.location = value; this.save(); })
          this.option('照片描述搜索', '按颜色、形状等描述查找已保存的物品照片。', this.photo,
            (value: boolean) => { this.photo = value; this.save(true); })
          this.option('备份进度实况窗', '在耗时的备份和恢复中，离开应用也能查看操作进度。', this.live,
            (value: boolean) => { this.live = value; this.save(); })
          Text('系统入口的可用性取决于设备支持情况。')
            .fontSize(13).fontColor($r('app.color.text_secondary'))
          if (this.message.length > 0) { Text(this.message).fontSize(14).fontColor($r('app.color.text_secondary')) }
          if (!this.ready) { Button('重新读取设置').onClick(() => this.load()) }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(24).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).height('100%').width('100%').padding({ bottom: this.bottom })
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private header() { PageHeader({ title: '系统能力与隐私', subtitle: '让物品服务出现在需要的地方。', showBack: true }) }

  @Builder
  private option(title: string, description: string, enabled: boolean, change: (value: boolean) => void) {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Text(description).fontSize(13).fontColor($r('app.color.text_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: enabled }).enabled(this.ready && !this.busy)
        .selectedColor($r('app.color.brand_primary')).accessibilityText(title).onChange(change)
    }.width('100%').padding(16).borderRadius(16).backgroundColor($r('app.color.surface_card'))
  }

  private async load(): Promise<void> {
    try {
      const settings = await AppServices.get().systemFeatures.get();
      this.assistant = settings.assistantEnabled; this.search = settings.searchEnabled;
      this.location = settings.searchLocationVisible; this.photo = settings.photoSearchEnabled;
      this.live = settings.liveViewEnabled; this.ready = true;
    } catch (_) { this.message = '读取设置失败，请重试'; }
  }

  private async save(refreshPhotos: boolean = false): Promise<void> {
    if (!this.ready || this.busy) { return; }
    this.busy = true;
    try {
      const settings: SystemFeatures = { assistantEnabled: this.assistant, searchEnabled: this.search,
        searchLocationVisible: this.location, photoSearchEnabled: this.photo, liveViewEnabled: this.live };
      await AppServices.get().systemFeatures.save(settings);
      if (refreshPhotos) { await AppServices.get().photoSearch.refresh(); }
      this.message = '设置已保存';
    } catch (_) { this.message = '设置保存失败，请重试'; await this.load(); }
    finally { this.busy = false; }
  }
}
