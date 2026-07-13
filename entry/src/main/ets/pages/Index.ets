import { NavigationHelper } from '../navigation/NavigationHelper';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { MainEntryBar } from '../components/MainEntryBar';
import { AppEventBus } from '../common/AppEventBus';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { getUnhandledRouteRefreshAt } from '../navigation/RefreshContract';
import { RouteRefreshParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';
import { shouldShowRecentSection } from '../service/HomeSectionVisibility';
import { BatchFormPage } from './BatchFormPage';
import { BatchListPage } from './BatchListPage';
import { CategoryManagementPage } from './CategoryManagementPage';
import { ItemDetailPage } from './ItemDetailPage';
import { ItemFormPage } from './ItemFormPage';
import { ItemListPage } from './ItemListPage';
import { LendingPage } from './LendingPage';
import { LocationManagementPage } from './LocationManagementPage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @StorageLink('itemtrace.quickAddRequest') @Watch('onQuickAddRequested') private quickAddRequest: string = '';
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private dueSoonItems: ItemSummary[] = [];
  @State private outOfStockItems: ItemSummary[] = [];
  @State private dueSoonCount: number = 0;
  @State private outOfStockCount: number = 0;
  @State private locationPaths: string[] = [];
  @State private showRecentSection: boolean = true;
  @State private showExpirySection: boolean = true;
  @State private showStockSection: boolean = true;
  private dataRefreshListenerId: number = 0;
  private routeResultListenerId: number = 0;
  private quickAddOpening: boolean = false;
  private summaryLoadId: number = 0;
  private lastRouteRefreshAt: number = 0;
  private lastHandledDataRevision: number = -1;
  private lastHandledPreferenceRevision: number = -1;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    NavigationHelper.registerPathStack(this.pathStack);
    this.subscribeDataRefresh();
    this.subscribeRouteResultRefresh();
    this.refreshSummaryForCurrentRevision(true);
    this.openQuickAddIfRequested();
  }

  aboutToDisappear(): void {
    if (this.dataRefreshListenerId > 0) {
      AppEventBus.unsubscribeDataChanged(this.dataRefreshListenerId);
      this.dataRefreshListenerId = 0;
    }
    if (this.routeResultListenerId > 0) {
      NavigationHelper.unsubscribeRouteResult(this.routeResultListenerId);
      this.routeResultListenerId = 0;
    }
    NavigationHelper.unregisterPathStack(this.pathStack);
  }

  onPageShow(): void {
    if (!this.refreshForRevisionChange(false) && !this.handleRouteRefreshParams()) {
      this.refreshSummaryForCurrentRevision(false);
    }
    this.openQuickAddIfRequested();
  }

  private onQuickAddRequested(): void {
    this.openQuickAddIfRequested();
  }

  private onRevisionChanged(): void {
    this.refreshForRevisionChange(false);
  }

  private onRouteResult(result: Object | undefined): void {
    this.handleRouteRefreshParams(result as RouteRefreshParams | undefined);
  }

  private handleRouteRefreshParams(routeParams?: RouteRefreshParams): boolean {
    try {
      const params = routeParams ?? (NavigationHelper.getParams() as RouteRefreshParams | undefined);
      const refreshAt = getUnhandledRouteRefreshAt(params, this.lastRouteRefreshAt);
      if (refreshAt > 0) {
        this.lastRouteRefreshAt = refreshAt;
        this.refreshSummaryForCurrentRevision(false);
        return true;
      }
    } catch (_) {
    }
    return false;
  }

  private subscribeDataRefresh(): void {
    if (this.dataRefreshListenerId > 0) {
      return;
    }
    this.dataRefreshListenerId = AppEventBus.subscribeDataChanged(() => this.refreshForRevisionChange(false));
  }

  private subscribeRouteResultRefresh(): void {
    if (this.routeResultListenerId > 0) {
      return;
    }
    this.routeResultListenerId = NavigationHelper.subscribeRouteResult((result: Object | undefined) => this.onRouteResult(result));
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    const preferenceRevision = AppEventBus.currentPreferenceRevision();
    if (dataRevision === this.lastHandledDataRevision && preferenceRevision === this.lastHandledPreferenceRevision) {
      return false;
    }
    this.refreshSummaryForCurrentRevision(showLoading);
    return true;
  }

  private refreshSummaryForCurrentRevision(showLoading: boolean = false): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.lastHandledPreferenceRevision = AppEventBus.currentPreferenceRevision();
    this.loadSummary(showLoading);
  }

  private openQuickAddIfRequested(): void {
    if (this.quickAddRequest.length === 0 || this.quickAddOpening) {
      return;
    }
    const request = this.quickAddRequest;
    this.quickAddOpening = true;
    NavigationHelper.pushUrl({
      url: RouteName.ITEM_FORM,
      params: { mode: 'create', returnTo: RouteName.HOME }
    }).then((opened: boolean) => {
      this.quickAddOpening = false;
      if (!opened) {
        return;
      }
      if (this.quickAddRequest === request) {
        AppStorage.setOrCreate<string>('itemtrace.quickAddRequest', '');
      } else {
        this.openQuickAddIfRequested();
      }
    });
  }

  build() {
    Navigation(this.pathStack) {
      this.homeContent()
    }
    .hideTitleBar(true)
    .navDestination(this.navDestinationBuilder)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private homeContent() {
    Column() {
      if (this.loading) {
        LoadingState({ text: '正在整理你的物品清单…' })
      } else if (this.errorMessage.length > 0) {
        Column({ space: $r('app.float.space_3') }) {
          ErrorState({ message: this.errorMessage })
          Button('重新加载')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.refreshSummaryForCurrentRevision(true))
        }
        .padding($r('app.float.space_4'))
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_6') }) {
            this.hero()
            this.overview()
            if (this.locationPaths.length > 0) {
              this.locationShortcutSection()
            }
            if (shouldShowRecentSection(this.showRecentSection)) {
              this.summarySection('最近添加', '刚记录的物品', this.recentItems, '暂无物品', RouteName.ITEM_FORM, RouteName.HOME)
            }
            if (this.showExpirySection) {
              this.summarySection('即将到期', '优先处理，避免浪费', this.dueSoonItems, '暂无即将到期物品', RouteName.ITEM_LIST)
            }
            if (this.showStockSection) {
              this.summarySection('待补货', '数量为 0 的物品', this.outOfStockItems, '暂无待补货物品', RouteName.ITEM_LIST)
            }
          }
          .width('100%')
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }

      MainEntryBar({ activeRoute: RouteName.HOME })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private navDestinationBuilder(name: string, param: Object) {
    NavDestination() {
      if (name === RouteName.ITEM_LIST) {
        ItemListPage()
      } else if (name === RouteName.ITEM_DETAIL) {
        ItemDetailPage()
      } else if (name === RouteName.ITEM_FORM) {
        ItemFormPage()
      } else if (name === RouteName.SEARCH) {
        SearchPage()
      } else if (name === RouteName.SETTINGS) {
        SettingsPage()
      } else if (name === RouteName.BATCH_LIST) {
        BatchListPage()
      } else if (name === RouteName.BATCH_FORM) {
        BatchFormPage()
      } else if (name === RouteName.LENDING) {
        LendingPage()
      } else if (name === RouteName.LOCATION_MANAGEMENT) {
        LocationManagementPage()
      } else if (name === RouteName.CATEGORY_MANAGEMENT) {
        CategoryManagementPage()
      } else {
        ErrorState({ message: '页面不存在，请返回首页后重试' })
      }
    }
    .hideTitleBar(true)
    .onBackPressed(() => NavigationHelper.handleBackPressed())
  }

  @Builder
  private hero() {
    Column({ space: $r('app.float.space_4') }) {
      Row({ space: $r('app.float.space_2') }) {
        Text('IT')
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius(16)
          .padding({ left: $r('app.float.space_2'), right: $r('app.float.space_2'), top: $r('app.float.space_1'), bottom: $r('app.float.space_1') })
        Text('ITEMTRACE')
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
      }
      Text('物品，有迹可循')
        .fontSize($r('app.float.font_display'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('把位置、数量和到期日记下来；需要时，随时找到。')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
      Row({ space: $r('app.float.space_2') }) {
        Button('+ 记录物品')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create', returnTo: RouteName.HOME } }))
        Button('搜索')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SEARCH }))
        Button('设置')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SETTINGS }))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_6'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private overview() {
    Row({ space: $r('app.float.space_2') }) {
      this.metricCard('最近添加', this.recentItems.length, $r('app.color.surface_accent'), $r('app.color.brand_primary'))
      this.metricCard('即将到期', this.dueSoonCount, $r('app.color.status_warning_soft'), $r('app.color.status_warning'))
      this.metricCard('待补货', this.outOfStockCount, $r('app.color.status_danger_soft'), $r('app.color.status_danger'))
    }
    .width('100%')
  }

  @Builder
  private metricCard(label: string, count: number, background: ResourceColor, textColor: ResourceColor) {
    Column({ space: $r('app.float.space_1') }) {
      Text(count.toString())
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
        .contentTransition(new NumericTextTransition())
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor(textColor)
    }
    .layoutWeight(1)
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor(background)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private locationShortcutSection() {
    Column({ space: $r('app.float.space_3') }) {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text('按位置找')
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('从常用位置直接查看物品')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Button('全部')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_app'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST }))
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.locationPaths, (location: string) => {
          Button(location)
            .type(ButtonType.Capsule)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_accent'))
            .fontSize($r('app.float.font_caption'))
            .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
            .onClick(() => this.openLocationList(location))
        }, (location: string) => location)
      }
    }
    .width('100%')
    .padding($r('app.float.space_4'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private summarySection(title: string, subtitle: string, items: ItemSummary[], emptyText: string, actionRoute: string, actionReturnTo: string = '') {
    Column({ space: $r('app.float.space_3') }) {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text(title)
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Text(`${items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (items.length === 0) {
        EmptyState({
          title: emptyText,
          description: this.summaryEmptyDescription(title),
          actionText: this.summaryEmptyActionText(title),
          actionRoute: actionRoute,
          actionMode: actionRoute === RouteName.ITEM_FORM ? 'create' : '',
          actionReturnTo: actionReturnTo
        })
      } else {
        ForEach(items, (item: ItemSummary) => {
          ItemCard({ item: item })
        }, (item: ItemSummary) => item.id)
      }
    }
    .width('100%')
  }

  private async loadSummary(showLoading: boolean = true): Promise<void> {
    const loadId = ++this.summaryLoadId;
    if (showLoading) {
      this.loading = true;
      this.errorMessage = '';
    }
    try {
      const preferencesResult = await AppServices.get().preferences.get();
      if (loadId !== this.summaryLoadId) {
        return;
      }
      if (preferencesResult.ok) {
        this.showRecentSection = preferencesResult.getData().showRecentSection;
        this.showExpirySection = preferencesResult.getData().showExpirySection;
        this.showStockSection = preferencesResult.getData().showStockSection;
      }
      const result = await AppServices.get().homeSummary.getSummary();
      if (loadId !== this.summaryLoadId) {
        return;
      }
      if (!result.ok) {
        if (showLoading || this.recentItems.length + this.dueSoonItems.length + this.outOfStockItems.length === 0) {
          this.errorMessage = result.getError().message;
        }
        return;
      }
      this.errorMessage = '';
      const summary = result.getData();
      this.recentItems = summary.recentItems;
      this.dueSoonItems = summary.dueSoonItems;
      this.outOfStockItems = summary.outOfStockItems;
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.dueSoonCount = summary.dueSoonCount;
        this.outOfStockCount = summary.outOfStockCount;
      });
      await this.loadLocationShortcuts(loadId);
    } catch (_) {
      if (loadId === this.summaryLoadId && (showLoading || this.recentItems.length + this.dueSoonItems.length + this.outOfStockItems.length === 0)) {
        this.errorMessage = '数据库初始化失败，请重试';
      }
    } finally {
      if (loadId === this.summaryLoadId) {
        this.loading = false;
      }
    }
  }

  private async loadLocationShortcuts(loadId: number): Promise<void> {
    const result = await AppServices.get().searchItems.getFilterOptions();
    if (loadId === this.summaryLoadId && result.ok) {
      this.locationPaths = result.getData().locationPaths.slice(0, 6);
    }
  }

  private openLocationList(location: string): void {
    NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { query: new ItemQuery('', location) } });
  }

  private summaryEmptyDescription(title: string): string {
    if (title === '最近添加') {
      return '先记录一个物品，首页会自动显示最近内容。';
    }
    if (title === '即将到期') {
      return '目前没有需要优先处理的到期物品。';
    }
    if (title === '待补货') {
      return '数量为 0 的物品会自动出现在这里。';
    }
    return '';
  }

  private summaryEmptyActionText(title: string): string {
    if (title === '最近添加') {
      return '新增物品';
    }
    return '查看全部';
  }
}
