import { PageHeader } from '../components/PageHeader';
import { LoadingState } from '../components/LoadingState';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { OutstandingItemLoan } from '../model/TraceEvent';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';
import { nativeTitleOptions, RoundedButtonStyle } from '../ui/VisualStyle';

@Component
export struct OutstandingLoansPage {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.dataRevision') @Watch('refresh') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private loans: OutstandingItemLoan[] = [];
  private requests: LatestRequestCoordinator = new LatestRequestCoordinator();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.refresh(); }
  aboutToDisappear(): void { this.requests.invalidate(); }

  private async refresh(): Promise<void> {
    const request = this.requests.begin();
    try {
      const result = await AppServices.get().lending.getOutstandingLoans();
      if (!this.requests.isCurrent(request)) { return; }
      if (result.ok) { this.loans = result.getData(); this.errorMessage = ''; }
      else { this.errorMessage = result.getError().message; }
    } catch (_) {
      if (this.requests.isCurrent(request)) { this.errorMessage = '读取待归还物品失败，请重试'; }
    } finally {
      if (this.requests.isCurrent(request)) { this.loading = false; }
    }
  }

  @Builder
  private header() {
    PageHeader({ title: '借出未还', subtitle: '借给谁、还剩多少，一起看清。', showBack: true })
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.loading) { LoadingState({ text: '正在整理借出记录…' }) }
          else if (this.errorMessage.length > 0) {
            ErrorState({ message: this.errorMessage })
            Button('重新读取').attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).onClick(() => this.refresh())
          } else if (this.loans.length === 0) {
            EmptyState({ title: '目前没有借出未还的物品', description: '借出物品时，在物品详情中记录借用人；待归还的物品会集中显示在这里。' })
          } else {
            Text(`还有 ${this.loans.length} 笔借出待归还`).fontSize(14).fontColor($r('app.color.text_secondary'))
            ForEach(this.loans, (entry: OutstandingItemLoan) => {
              Column({ space: 12 }) {
                Text(entry.itemName).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                Text(`借给 ${entry.loan.borrowEvent.counterpart ?? '未填写借用人'} · 待还 ${entry.loan.remainingQuantity}${entry.unit}`)
                  .fontSize(15).fontColor($r('app.color.text_primary'))
                Text(`借出于 ${new Date(entry.loan.borrowEvent.createdAt).toLocaleDateString()}`)
                  .fontSize(12).fontColor($r('app.color.text_secondary'))
                Row({ space: 12 }) {
                  Button('记录归还').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .layoutWeight(1).fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
                    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LENDING,
                      params: { itemId: entry.itemId, borrowEventId: entry.loan.borrowEvent.id } }))
                  Button('查看物品').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .layoutWeight(1).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
                    .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: entry.itemId } }))
                }.width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
                .backgroundColor($r('app.color.surface_card')).borderRadius(20)
            }, (entry: OutstandingItemLoan) => entry.loan.borrowEvent.id)
          }
        }.width('100%').constraintSize({ maxWidth: 880 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 24, right: 24, bottom: 24 + this.safeAreaBottom })
      }.width('100%').height('100%').align(Alignment.TopStart)
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).bindToScrollable([this.scroller]).backgroundColor($r('app.color.surface_app'))
      .onShown(() => this.refresh())
  }
}
