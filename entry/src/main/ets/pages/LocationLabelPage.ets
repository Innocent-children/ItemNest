import { PageHeader } from '../components/PageHeader';
import { AppServices } from '../service/AppServices';
import { LocationLabel } from '../model/LocationLabel';
import { NfcLabelAdapter } from '../service/adapter/NfcLabelAdapter';
import { ExternalRequestParser } from '../navigation/ExternalRequestParser';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { NavigationRouteParams } from '../navigation/RouteContract';
import { nativeTitleOptions } from '../ui/VisualStyle';
import { LocationRecord } from '../model/Location';
import { common } from '@kit.AbilityKit';

@Component
export struct LocationLabelPage {
  @StorageLink('itemnest.uiForeground') @Watch('foregroundChanged') private foreground: boolean = true;
  @StorageLink('itemnest.safeAreaBottom') private bottom: number = 0;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private locationId: string = '';
  @State private locations: LocationRecord[] = [];
  @State private labels: LocationLabel[] = [];
  @State private token: string = '';
  @State private uri: string = '';
  @State private message: string = '';
  @State private busy: boolean = false;
  @State private listening: boolean = false;
  private nfc: NfcLabelAdapter = new NfcLabelAdapter();

  aboutToAppear(): void {
    this.locationId = (NavigationHelper.getParams() as NavigationRouteParams | undefined)?.locationId ?? '';
    this.load();
  }
  private foregroundChanged(): void {
    if (!this.foreground) { this.nfc.stop(); this.listening = false; }
  }
  aboutToDisappear(): void { this.nfc.stop(); }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('选择收纳位置，为它生成二维码或写入 NFC 标签。标签只保存关联标识。')
            .fontSize(14).fontColor($r('app.color.text_secondary'))
          Select(this.locations.map((location: LocationRecord): SelectOption => ({ value: location.path })))
            .value(this.locations.find((location: LocationRecord) => location.id === this.locationId)?.path ?? '选择位置')
            .enabled(!this.busy && !this.listening)
            .onSelect((index: number) => { this.locationId = this.locations[index].id; this.token = ''; this.uri = ''; })
          Button('生成新标签').enabled(this.locationId.length > 0 && !this.busy && !this.listening).onClick(() => this.createLabel())
          ForEach(this.labels.filter((label: LocationLabel) => label.locationId === this.locationId), (label: LocationLabel) => {
            Button('查看标签 ' + label.token.slice(0, 8)).enabled(!this.busy && !this.listening)
              .onClick(() => this.selectLabel(label))
          }, (label: LocationLabel) => label.token)
          if (this.uri.length > 0) {
            QRCode(this.uri).width(240).height(240).color('#17242D').backgroundColor('#FFFFFF')
            Text(this.locations.find((location: LocationRecord) => location.id === this.locationId)?.path ?? '')
              .fontSize(16).fontColor($r('app.color.text_primary'))
            Button('分享标签链接').enabled(!this.busy).onClick(() => this.share())
            Button('将标签写入 NFC').enabled(!this.busy && !this.listening).onClick(() => this.startNfc(true))
            Button('解除这个标签的关联').enabled(!this.busy && !this.listening).onClick(() => this.remove())
          }
          Button('扫描已有二维码，重新绑定到此位置').enabled(this.locationId.length > 0 && !this.busy && !this.listening)
            .onClick(() => this.scan())
          Button('读取 NFC，重新绑定到此位置').enabled(this.locationId.length > 0 && !this.busy && !this.listening)
            .onClick(() => this.startNfc(false))
          if (this.listening) { Button('停止 NFC 读写').onClick(() => { this.nfc.stop(); this.listening = false; }) }
          if (this.message.length > 0) { Text(this.message).fontSize(14).fontColor($r('app.color.text_secondary')) }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(24)
      }.align(Alignment.TopStart).width('100%').height('100%').padding({ bottom: this.bottom })
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).backgroundColor($r('app.color.surface_app'))
      .onHidden(() => { this.nfc.stop(); this.listening = false; })
  }
  @Builder
  private header() { PageHeader({ title: '收纳标签', subtitle: '碰一下或扫一扫，找到箱内物品。', showBack: true }) }

  private async load(): Promise<void> {
    try {
      const locations = await AppServices.get().locations.list();
      if (!locations.ok) { throw locations.getError(); }
      this.locations = locations.getData().filter((location: LocationRecord) => location.active);
      this.labels = await AppServices.get().locationLabels.list();
    } catch (_) { this.message = '读取位置或标签失败，请重试'; }
  }
  private selectLabel(label: LocationLabel): void {
    this.token = label.token; this.uri = AppServices.get().locationLabels.uri(label);
  }
  private async createLabel(): Promise<void> {
    this.busy = true;
    try { this.selectLabel(await AppServices.get().locationLabels.create(this.locationId)); await this.load(); }
    catch (_) { this.message = '创建标签失败，请重试'; }
    finally { this.busy = false; }
  }
  private async remove(): Promise<void> {
    const response = await this.getUIContext().getPromptAction().showDialog({ title: '解除标签关联？',
      message: '解除后，原二维码和 NFC 标签将无法打开这个位置。', buttons: [{ text: '取消', color: '#666666' }, { text: '解除', color: '#C0392B' }] });
    if (response.index !== 1) { return; }
    this.busy = true;
    try { await AppServices.get().locationLabels.remove(this.token); this.uri = ''; this.token = ''; await this.load(); }
    catch (_) { this.message = '解除关联失败，请重试'; }
    finally { this.busy = false; }
  }
  private startNfc(write: boolean): void {
    this.listening = true; this.message = write ? '请将手机贴近可写入的 NFC 标签，将覆盖原有标签内容。' : '请将手机贴近 我的家当 NFC 标签。';
    this.nfc.start(write ? this.uri : undefined, (uri: string, error: string) => {
      if (error.length > 0) { this.message = error; this.nfc.stop(); this.listening = false; return; }
      this.listening = false;
      if (write) { this.message = 'NFC 标签已写入'; } else { this.bindLabel(uri); }
    });
  }
  private async scan(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const result = await AppServices.get().scan.scan(context);
    if (!result.ok) { this.message = result.getError().message; }
    else if (result.getData() !== undefined) { await this.bindLabel(result.getData()!); }
  }
  private async bindLabel(uri: string): Promise<void> {
    const request = ExternalRequestParser.parseUri(uri);
    if (request?.action !== 'location' || request.locationId === undefined) { this.message = '这不是 我的家当 收纳标签'; return; }
    this.busy = true;
    try {
      await AppServices.get().locationLabels.bind(request.locationId, this.locationId);
      this.selectLabel({ token: request.locationId, locationId: this.locationId }); await this.load(); this.message = '已重新绑定';
    } catch (_) { this.message = '重新绑定失败，请重试'; }
    finally { this.busy = false; }
  }
  private async share(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await AppServices.get().sharing.share(context, '收纳位置标签', this.uri);
    } catch (_) { this.message = '分享暂不可用，请重试'; }
  }
}
