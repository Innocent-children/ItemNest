import { NavigationHelper } from '../navigation/NavigationHelper';
import { accessibility } from '@kit.AccessibilityKit';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { MainEntryBar } from '../components/MainEntryBar';
import { AppEventBus } from '../common/AppEventBus';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { LowStockItem } from '../model/StockThreshold';
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

interface HomeMetricParams {
  label: string;
  count: number;
  background: ResourceColor;
  textColor: ResourceColor;
}

interface HomeSummarySectionParams {
  title: string;
  subtitle: string;
  items: ItemSummary[];
  emptyText: string;
  actionRoute: string;
  actionReturnTo?: string;
}

@Entry
@Component
struct Index {
  @StorageLink('itemtrace.quickAddRequest') @Watch('onQuickAddRequested') private quickAddRequest: string = '';
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private dueSoonItems: ItemSummary[] = [];
  @State private outOfStockItems: ItemSummary[] = [];
  @State private lowStockItems: LowStockItem[] = [];
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
  private animationReduceListener: (enabled: boolean) => void = (enabled: boolean) => {
    this.applyAnimationPreference(enabled);
  };

  aboutToAppear(): void {
    try {
      this.applyAnimationPreference(accessibility.isAnimationReduceEnabledSync());
      accessibility.onAnimationReduceStateChange(this.animationReduceListener);
    } catch (_) {
    }
    NavigationHelper.registerPathStack(this.pathStack);
    this.subscribeDataRefresh();
    this.subscribeRouteResultRefresh();
    this.refreshSummaryForCurrentRevision(true);
    this.openQuickAddIfRequested();
  }

  aboutToDisappear(): void {
    try {
      accessibility.offAnimationReduceStateChange(this.animationReduceListener);
    } catch (_) {
    }
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

  private applyAnimationPreference(enabled: boolean): void {
    this.reduceAnimation = enabled;
    AppStorage.setOrCreate<boolean>('itemtrace.reduceAnimation', enabled);
    this.pathStack.disableAnimation(enabled);
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
    .onNavBarStateChange((visible: boolean) => {
      if (visible) {
        this.refreshSummaryForCurrentRevision(false);
      }
    })
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
          Row() {
            Column({ space: $r('app.float.space_6') }) {
              this.hero()
              this.overview()
              if (this.locationPaths.length > 0) {
                this.locationShortcutSection()
              }
              if (shouldShowRecentSection(this.showRecentSection)) {
                this.summarySection({ title: '最近添加', subtitle: '刚记录的物品', items: this.recentItems, emptyText: '暂无物品', actionRoute: RouteName.ITEM_FORM, actionReturnTo: RouteName.HOME })
              }
              if (this.showExpirySection) {
                this.summarySection({ title: '即将到期', subtitle: '优先处理，避免浪费', items: this.dueSoonItems, emptyText: '暂无即将到期物品', actionRoute: RouteName.ITEM_LIST })
              }
              if (this.showStockSection) {
                this.summarySection({ title: '待补货', subtitle: '数量为 0 的物品', items: this.outOfStockItems, emptyText: '暂无待补货物品', actionRoute: RouteName.ITEM_LIST })
                if (this.lowStockItems.length > 0) {
                  this.lowStockSection()
                }
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: 960 })
            .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
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
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 16 }))
      .animation({ duration: this.reduceAnimation ? 0 : 280, curve: Curve.EaseOut }))
  }

  @Builder
  private overview() {
    Row({ space: $r('app.float.space_2') }) {
      this.metricCard({ label: '最近添加', count: this.recentItems.length, background: $r('app.color.surface_accent'), textColor: $r('app.color.brand_primary') })
      this.metricCard({ label: '即将到期', count: this.dueSoonCount, background: $r('app.color.status_warning_soft'), textColor: $r('app.color.status_warning') })
      this.metricCard({ label: '待补货', count: this.outOfStockCount, background: $r('app.color.status_danger_soft'), textColor: $r('app.color.status_danger') })
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation({ duration: this.reduceAnimation ? 0 : 280, curve: Curve.EaseOut }))
  }

  @Builder
  private metricCard($$: HomeMetricParams) {
    Column({ space: $r('app.float.space_1') }) {
      Text($$.count.toString())
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($$.textColor)
      Text($$.label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($$.textColor)
    }
    .layoutWeight(1)
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($$.background)
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
  private summarySection($$: HomeSummarySectionParams) {
    Column({ space: $r('app.float.space_3') }) {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text($$.title)
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($$.subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Text(`${$$.items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if ($$.items.length === 0) {
        EmptyState({
          title: $$.emptyText,
          description: this.summaryEmptyDescription($$.title),
          actionText: this.summaryEmptyActionText($$.title),
          actionRoute: $$.actionRoute,
          actionMode: $$.actionRoute === RouteName.ITEM_FORM ? 'create' : '',
          actionReturnTo: $$.actionReturnTo ?? ''
        })
      } else {
        ForEach($$.items, (item: ItemSummary) => {
          ItemCard({ item: item })
        }, (item: ItemSummary) => `${item.id}:${item.updatedAt}:${item.expiryStatus}:${item.quantity}`)
      }
    }
    .width('100%')
  }

  @Builder
  private lowStockSection() {
    Column({ space: $r('app.float.space_3') }) {
      Text('低库存')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('低于你为物品设置的阈值，仅在应用内提示。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      ForEach(this.lowStockItems, (item: LowStockItem) => {
        Row({ space: $r('app.float.space_3') }) {
          Text(item.name)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(`${item.quantity} / 阈值 ${item.threshold}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.status_danger'))
        }
        .width('100%')
        .padding($r('app.float.space_3'))
        .borderRadius($r('app.float.radius_control'))
        .backgroundColor($r('app.color.surface_card'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({ duration: this.reduceAnimation ? 0 : 240, curve: Curve.EaseOut }))
        .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: item.itemId } }))
      }, (item: LowStockItem) => item.itemId)
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
      if (this.reduceAnimation) {
        this.dueSoonCount = summary.dueSoonCount;
        this.outOfStockCount = summary.outOfStockCount;
      } else {
        this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
          this.dueSoonCount = summary.dueSoonCount;
          this.outOfStockCount = summary.outOfStockCount;
        });
      }
      await this.loadLocationShortcuts(loadId);
      const lowStock = await AppServices.get().lowStock.listLowStock();
      if (loadId === this.summaryLoadId) {
        this.lowStockItems = lowStock.ok ? lowStock.getData() : [];
      }
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
