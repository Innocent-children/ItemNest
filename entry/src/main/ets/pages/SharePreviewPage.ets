import { localImageSource } from '../ui/ImageSource';
import { common } from '@kit.AbilityKit';
import { PageHeader } from '../components/PageHeader';
import { AppServices } from '../service/AppServices';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { NavigationRouteParams } from '../navigation/RouteContract';
import { Item } from '../model/Item';
import { OutstandingItemLoan } from '../model/TraceEvent';
import { nativeTitleOptions } from '../ui/VisualStyle';

@Component
export struct SharePreviewPage {
  @StorageLink('itemnest.safeAreaBottom') private bottom: number = 0;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private withLocation: boolean = false;
  @State private withNotes: boolean = false;
  @State private withPerson: boolean = false;
  @State private withPhoto: boolean = false;
  private loanLocations: Map<string, string> = new Map<string, string>();
  @State private items: Item[] = [];
  @State private loans: OutstandingItemLoan[] = [];
  @State private photoPath: string = '';
  @State private title: string = '物品清单';
  @State private message: string = '';
  @State private ready: boolean = false;
  @State private busy: boolean = false;

  aboutToAppear(): void { this.load(); }
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('选择要分享的内容，确认预览后再发送。').fontSize(14).fontColor($r('app.color.text_secondary'))
          this.option('包含存放位置', this.withLocation, (value: boolean) => this.withLocation = value)
          this.option('包含备注', this.withNotes, (value: boolean) => this.withNotes = value)
          if (this.loans.length > 0) { this.option('包含借用人', this.withPerson, (value: boolean) => this.withPerson = value) }
          if (this.photoPath.length > 0) { this.option('包含物品照片', this.withPhoto, (value: boolean) => this.withPhoto = value) }
          Text(this.preview()).fontSize(16).fontColor($r('app.color.text_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
          if (this.withPhoto) { Image(localImageSource(this.photoPath)).width('100%').height(220).objectFit(ImageFit.Contain) }
          if (this.message.length > 0) { Text(this.message).fontSize(14).fontColor($r('app.color.text_secondary')) }
          Button(this.busy ? '正在打开分享…' : '确认并打开系统分享').enabled(this.ready && !this.busy).onClick(() => this.share())
          if (!this.ready) { Button('重新加载').onClick(() => this.load()) }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(24).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).width('100%').height('100%').padding({ bottom: this.bottom })
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).backgroundColor($r('app.color.surface_app'))
  }
  @Builder
  private header() { PageHeader({ title: '分享预览', subtitle: '由你决定分享哪些信息。', showBack: true }) }
  @Builder
  private option(title: string, on: boolean, change: (value: boolean) => void) {
    Row() {
      Text(title).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: on }).enabled(!this.busy).accessibilityText(title).onChange(change)
    }.width('100%')
  }
  private async load(): Promise<void> {
    const params = NavigationHelper.getParams() as NavigationRouteParams | undefined;
    this.ready = false; this.message = '';
    try {
      const services = AppServices.get();
      if (params?.itemId !== undefined) {
        const item = await services.detailItem.getDetail(params.itemId);
        if (!item.ok) { throw item.getError(); }
        this.items = [item.getData()]; this.title = item.getData().name;
        const photo = await services.photos.getLocalPath(item.getData());
        if (photo.ok) { this.photoPath = photo.getData() ?? ''; }
      } else if (params?.section === 'loans') {
        const loans = await services.lending.getOutstandingLoans();
        if (!loans.ok) { throw loans.getError(); }
        const items = await services.repository.listAll();
        if (!items.ok) { throw items.getError(); }
        this.loanLocations.clear();
        for (const item of items.getData()) {
          this.loanLocations.set(item.id, item.activeLocationPaths?.join('、') || item.locationPath || '未填写');
        }
        this.loans = loans.getData(); this.title = '借出待还清单';
      } else {
        const locations = await services.locations.list();
        if (!locations.ok) { throw locations.getError(); }
        const location = locations.getData().find(value => value.id === params?.locationId && value.active);
        if (location === undefined) { throw new Error('位置不存在'); }
        const items = await services.repository.listAll();
        if (!items.ok) { throw items.getError(); }
        this.items = items.getData().filter((item: Item) =>
          (item.activeLocationPaths ?? [item.locationPath ?? '']).some((path: string) =>
            path === location.path || path.startsWith(location.path + ' / ')));
      }
      this.ready = true;
    } catch (_) { this.message = '无法读取分享内容，请返回后重试'; }
  }
  private preview(): string {
    const lines: string[] = [this.title];
    for (const item of this.items) {
      let line = item.name + ' · ' + item.quantity + item.unit;
      if (this.withLocation) { line += '\n位置：' + (item.activeLocationPaths?.join('、') || item.locationPath || '未填写'); }
      if (this.withNotes && item.notes) { line += '\n备注：' + item.notes; }
      lines.push(line);
    }
    for (const loan of this.loans) {
      let line = loan.itemName + ' · 待还 ' + loan.loan.remainingQuantity + loan.unit +
        ' · 借出于 ' + new Date(loan.loan.borrowEvent.createdAt).toLocaleDateString();
      if (this.withLocation) { line += '\n位置：' + (this.loanLocations.get(loan.itemId) || '未填写'); }
      if (this.withPerson) { line += '\n借用人：' + (loan.loan.borrowEvent.counterpart || '未填写'); }
      if (this.withNotes && loan.loan.borrowEvent.note) { line += '\n备注：' + loan.loan.borrowEvent.note; }
      lines.push(line);
    }
    return lines.join('\n\n');
  }
  private async share(): Promise<void> {
    this.busy = true;
    try {
      const text = this.preview();
      if (text.length > 30000) { this.message = '清单内容较多，请选择更小的收纳位置分享'; return; }
      await AppServices.get().sharing.share(this.getUIContext().getHostContext() as common.UIAbilityContext,
        this.title, text, this.withPhoto ? this.photoPath : undefined);
    } catch (_) { this.message = '无法打开系统分享，请重试'; }
    finally { this.busy = false; }
  }
}
