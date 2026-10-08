import { PageHeader } from '../components/PageHeader';
import { LoadingState } from '../components/LoadingState';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { TraceEvent, TraceEventType } from '../model/TraceEvent';
import { ItemUnit } from '../model/Item';
import { ItemRouteParams, requireItemId } from '../navigation/RouteContract';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';
import { historyEventLabel, historyTime } from '../service/ItemHistoryService';
import { RoundedButtonStyle, nativeTitleOptions } from '../ui/VisualStyle';

@Component
export struct ItemHistoryPage {
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private name: string = '';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private events: TraceEvent[] = [];
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  private itemId: string = '';
  private scroller: Scroller = new Scroller();
  private requests: LatestRequestCoordinator = new LatestRequestCoordinator();

  aboutToAppear(): void {
    const result = requireItemId(NavigationHelper.getParams() as ItemRouteParams | undefined);
    if (!result.ok) { this.errorMessage = result.getError().message; this.loading = false; return; }
    this.itemId = result.getData();
  }

  aboutToDisappear(): void { this.requests.begin(); }

  private async refresh(): Promise<void> {
    if (!this.itemId) { return; }
    const request = this.requests.begin();
    try {
      const item = await AppServices.get().detailItem.getDetail(this.itemId);
      const events = await AppServices.get().history.list(this.itemId);
      if (!this.requests.isCurrent(request)) { return; }
      if (!item.ok) { this.errorMessage = item.getError().message; return; }
      if (!events.ok) { this.errorMessage = events.getError().message; return; }
      this.name = item.getData().name;
      this.unit = item.getData().unit;
      this.events = events.getData();
      this.errorMessage = '';
    } catch (_) {
      if (this.requests.isCurrent(request)) { this.errorMessage = '读取使用记录失败，请重试'; }
    } finally { if (this.requests.isCurrent(request)) { this.loading = false; } }
  }

  @Builder
  private header() {
    PageHeader({ title: '使用记录', subtitle: this.name, showBack: true })
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          if (this.loading) { LoadingState({ text: '正在读取使用记录…' }) }
          else if (this.errorMessage.length > 0) {
            ErrorState({ message: this.errorMessage })
            Button('重新读取').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).onClick(() => this.refresh())
          } else if (this.events.length === 0) {
            EmptyState({ title: '还没有使用记录', description: '之后的补入、用量、位置调整和借还会记录在这里。' })
          } else {
            ForEach(this.events, (event: TraceEvent) => {
              Column({ space: 8 }) {
                Text(`${historyEventLabel(event.type)}${event.type === TraceEventType.MOVE ? '' : ` ${event.quantity}${this.unit}`}${event.voidedAt === undefined ? '' : ' · 已撤销'}`)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Text(historyTime(event.createdAt)).fontSize(12).fontColor($r('app.color.text_secondary'))
                if (event.counterpart) { Text(`借用人：${event.counterpart}`).fontSize(14).fontColor($r('app.color.text_primary')) }
                if (event.note) { Text(event.note).fontSize(13).fontColor($r('app.color.text_secondary')) }
                if (event.type === TraceEventType.BORROW || event.type === TraceEventType.RETURN) {
                  Button('查看借还').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
                    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LENDING, params: { itemId: this.itemId } }))
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
                .borderRadius(16).backgroundColor($r('app.color.surface_card'))
            }, (event: TraceEvent) => `${event.id}-${event.voidedAt ?? 0}-${event.quantity}`)
          }
        }.width('100%').constraintSize({ maxWidth: 880 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 24, right: 24, bottom: 24 + this.safeAreaBottom })
      }.width('100%').height('100%').align(Alignment.TopStart)
        .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).bindToScrollable([this.scroller]).backgroundColor($r('app.color.surface_app'))
      .onShown(() => this.refresh())
  }
}
