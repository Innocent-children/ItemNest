import { localImageSource } from '../ui/ImageSource';
import { ItemHeroMotion, ItemHeroSource } from '../ui/ItemHeroMotion';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, dockContentInset, uiSpring, FloatingTabsStyle, nativeTitleOptions, numericMotion } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { accessibility } from '@kit.AccessibilityKit';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { MainDock } from '../components/MainDock';
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

interface AttentionMetricParams {
  count: number;
  label: string;
  icon: Resource;
}

interface HomeSummarySectionParams {
  title: string;
  items: ItemSummary[];
  emptyText: string;
  expandableExpiry?: boolean;
}

@Entry
@Component
struct Index {
  @StorageLink('itemtrace.quickAddRequest') @Watch('onQuickAddRequested') private quickAddRequest: string = '';
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private mainTabIndex: number = 0;
  @State private selectedTabIndex: number = 0;
  @State private navigationRootVisible: boolean = true;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @State private dockRoute: string = RouteName.HOME;
  private mainTabRoutes: string[] = [RouteName.HOME, RouteName.ITEM_LIST, RouteName.SEARCH, RouteName.SETTINGS];
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private dueSoonItems: ItemSummary[] = [];
  @State private expiryAttentionItems: ItemSummary[] = [];
  @State private showAllExpiryItems: boolean = false;
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
  @State private searchEntryVisible: boolean = true;
  private searchTransition: boolean = false;
  @State private heroVisible: boolean = false;
  @State private heroPhoto: string = '';
  @State private heroX: number = 0;
  @State private heroY: number = 0;
  @State private heroWidth: number = 52;
  @State private heroHeight: number = 60;
  @State private heroRadius: number = 14;
  private homeScroller: Scroller = new Scroller();
  @State private homeScrolled: boolean = false;
  private tabsController: TabsController = new TabsController();
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
    ItemHeroMotion.register((source, proxy, operation, interactive) =>
      this.animateHero(source, proxy, operation, interactive), () => {
        this.heroVisible = false;
        AppStorage.setOrCreate<string>('itemtrace.heroSourceKey', '');
        AppStorage.setOrCreate<string>('itemtrace.heroActiveItem', '');
        AppStorage.setOrCreate<number>('itemtrace.heroContentOpacity', 1);
      });
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
    ItemHeroMotion.unregister();
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
    if (enabled) {
      this.searchEntryVisible = true;
      AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', true);
    }
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

  /**
   * 主栏目切换保留各页面内容；详情、表单和筛选列表使用导航栈。
   */
  private selectMainTab(route: string): void {
    const index = this.mainTabRoutes.indexOf(route);
    if (index < 0 || route === this.dockRoute) {
      return;
    }
    this.tabsController.changeIndex(index);
  }

  onBackPress(): boolean {
    if (this.pathStack.size() === 0 && this.selectedTabIndex !== 0) {
      this.selectMainTab(RouteName.HOME);
      return true;
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Navigation(this.pathStack) {
        this.mainTabs()
      }
      .title({ builder: this.mainHeader, height: this.mainTabIndex === 0 ? 100 : 76 },
        nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true)
      .mode(NavigationMode.Auto)
      .navBarWidthRange([320, 420])
      .minContentWidth(420)
      .onNavBarStateChange((visible: boolean) => {
        this.navigationRootVisible = visible;
        if (visible) {
          this.dockRoute = this.mainTabRoutes[this.mainTabIndex];
          this.refreshSummaryForCurrentRevision(false);
        }
      })
      .navDestination(this.navDestinationBuilder)
      .customNavContentTransition((from, to, operation) =>
        this.reduceAnimation ? undefined : (ItemHeroMotion.transition(from, to, operation) ?? this.searchMotion(from, to, operation)))
      .width('100%').height('100%')
      .backgroundColor($r('app.color.surface_app'))

      if (this.heroVisible) {
        this.heroOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .id('itemtrace-motion-root')
    .padding({ top: this.safeAreaTop })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.surface_app'))
  }


  private openSearch(): void {
    this.searchTransition = !this.reduceAnimation;
    AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', this.reduceAnimation);
    NavigationHelper.pushUrl({ url: RouteName.SEARCH,
      params: { source: this.searchTransition ? 'home-search' : 'search' } });
  }

  private searchMotion(from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (!this.searchTransition ||
      !((operation === NavigationOperation.PUSH && to.name === RouteName.SEARCH && !from.name) ||
        (operation === NavigationOperation.POP && from.name === RouteName.SEARCH && !to.name))) {
      return undefined;
    }
    const push = operation === NavigationOperation.PUSH;
    return {
      timeout: 1000,
      transition: (proxy: NavigationTransitionProxy) => {
        this.getUIContext().animateTo({ duration: 360, curve: Curve.Friction,
          onFinish: () => proxy.finishTransition() }, () => {
          this.searchEntryVisible = !push;
          AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', push);
        });
      },
      onTransitionEnd: (success: boolean) => {
        if (success && push) { this.getUIContext().getFocusController().requestFocus('itemtrace-search-input'); }
        if (success && !push) { this.searchTransition = false; }
      }
    };
  }

  private animateHero(source: ItemHeroSource, proxy: NavigationTransitionProxy,
    operation: NavigationOperation, interactive: boolean): void {
    const target = source.target;
    if (target === undefined) { proxy.finishTransition(); return; }
    const push = operation === NavigationOperation.PUSH;
    const start = push ? source.frame : target;
    const end = push ? target : source.frame;
    const root = ItemHeroMotion.frame(this.getUIContext(), 'itemtrace-motion-root');
    const rootX = root?.x ?? 0;
    const rootY = (root?.y ?? 0) + this.safeAreaTop;
    this.heroPhoto = source.photoPath ?? '';
    this.heroX = start.x - rootX;
    this.heroY = start.y - rootY;
    this.heroWidth = start.width;
    this.heroHeight = start.height;
    this.heroRadius = push ? 14 : 18;
    this.heroVisible = true;
    AppStorage.setOrCreate<string>('itemtrace.heroSourceKey', source.key);
    AppStorage.setOrCreate<string>('itemtrace.heroActiveItem', source.item.id);
    AppStorage.setOrCreate<number>('itemtrace.heroContentOpacity', push ? 0 : 1);
    this.getUIContext().animateTo({ duration: 420, curve: interactive ? Curve.Linear : Curve.Friction,
      onFinish: () => { if (!interactive) { proxy.finishTransition(); } } }, () => {
      this.heroX = end.x - rootX;
      this.heroY = end.y - rootY;
      this.heroWidth = end.width;
      this.heroHeight = end.height;
      this.heroRadius = push ? 18 : 14;
      AppStorage.setOrCreate<number>('itemtrace.heroContentOpacity', push ? 1 : 0);
    });
  }

  @Builder
  private heroOverlay() {
    Stack() {
      if (this.heroPhoto.length > 0) {
        Image(localImageSource(this.heroPhoto)).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else {
        Image($r('app.media.ui_box')).width('46%').height('46%').fillColor($r('app.color.brand_primary'))
      }
    }.width(this.heroWidth).height(this.heroHeight).position({ x: this.heroX, y: this.heroY })
      .backgroundColor($r('app.color.surface_accent')).borderRadius(this.heroRadius).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no').zIndex(10)
  }

  @Builder
  private tabLabel(label: string, symbol: Resource, index: number) {
    MainDock({ label: label, symbol: symbol, selected: this.selectedTabIndex === index })
  }

  @Builder
  private mainHeader() {
    PageHeader({ title: this.mainTabIndex === 0 ? '物品，都有去处。' : this.mainTabIndex === 1 ? '我的物品' :
      this.mainTabIndex === 2 ? '查找物品' : '我的空间',
      subtitle: this.mainTabIndex === 0 ? 'ITEMTRACE / 物品收纳' : this.mainTabIndex === 1 ? '每一件，都好好收着。' :
        this.mainTabIndex === 2 ? '知道放在哪里，就少一点寻找。' : '让整理，更合你的习惯。',
      largeTitle: this.mainTabIndex === 0 && !this.homeScrolled,
      actionText: '记录新物品', actionIcon: $r('app.media.dock_add'),
      onAction: () => this.openCreateMenu() })
  }

  private async openCreateMenu(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '记录新物品', buttons: [
        { text: '手动记录', color: $r('app.color.brand_primary') },
        { text: '扫码录入', color: $r('app.color.brand_primary') },
        { text: '拍照记录', color: $r('app.color.brand_primary') }
      ]
    }).catch(() => undefined);
    if (result !== undefined) {
      NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM,
        params: { mode: 'create', returnTo: this.dockRoute,
          source: result.index === 1 ? 'scan' : result.index === 2 ? 'camera' : 'manual' } });
    }
  }

  @Builder
  private mainTabs() {
    Tabs({ index: this.mainTabIndex, controller: this.tabsController }) {
      TabContent() {
        this.homeContent()
      }.tabBar(this.tabLabel('首页', $r('sys.symbol.house'), 0))
      TabContent() {
        ItemListPage({ isMainTab: true })
      }.tabBar(this.tabLabel('物品', $r('sys.symbol.archivebox'), 1))
      TabContent() {
        SearchPage({ isMainTab: true })
      }.tabBar(this.tabLabel('查找', $r('sys.symbol.magnifyingglass'), 2))
      TabContent() {
        SettingsPage({ isMainTab: true })
      }.tabBar(this.tabLabel('我的', $r('sys.symbol.person'), 3))
    }
    .attributeModifier(new FloatingTabsStyle(this.reduceAnimation))
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .barHeight(this.keyboardVisible ? 0 : 64)
    .animationMode(AnimationMode.CONTENT_FIRST_WITH_JUMP)
    .animationCurve(Curve.EaseOut)
    .animationDuration(this.reduceAnimation ? 0 : 180)
    .scrollable(true)
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.surface_app'))
    .onSelected((index: number) => {
      this.selectedTabIndex = index;
      this.dockRoute = this.mainTabRoutes[index];
    })
    .onChange((index: number) => {
      this.mainTabIndex = index;
      if (this.navigationRootVisible) {
        this.dockRoute = this.mainTabRoutes[index];
      }
    })
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
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.refreshSummaryForCurrentRevision(true))
        }
        .padding($r('app.float.space_4'))
      } else {
        Scroll(this.homeScroller) {
          Row() {
            Column({ space: $r('app.float.space_5') }) {
              this.homeHeader()
              if (this.recentItems.length > 0 || this.locationPaths.length > 0 || this.dueSoonCount + this.outOfStockCount > 0) {
                this.hero()
              }
              if (this.locationPaths.length > 0) {
                this.locationShortcutSection()
              }
              if (shouldShowRecentSection(this.showRecentSection)) {
                this.summarySection({ title: '最近添加', items: this.recentItems, emptyText: '暂无物品' })
              }
              if (this.showExpirySection) {
                this.summarySection({ title: '到期待处理', items: this.showAllExpiryItems ? this.expiryAttentionItems : this.dueSoonItems, emptyText: '暂无到期待处理物品', expandableExpiry: true })
              }
              if (this.showStockSection) {
                this.summarySection({ title: '待补货', items: this.outOfStockItems, emptyText: '暂无待补货物品' })
                if (this.lowStockItems.length > 0) {
                  this.lowStockSection()
                }
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: 960 })
            .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), top: 8, bottom: dockContentInset(true, this.keyboardVisible, this.safeAreaBottom) })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .clip(false)
        .onDidScroll(() => { this.homeScrolled = this.homeScroller.currentOffset().yOffset > 32; })
        .layoutWeight(1)
      }

      if (this.loading || this.errorMessage.length > 0) {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private navDestinationBuilder(name: string, param: Object) {
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

  @Builder
  private homeHeader() {
    Column({ space: 24 }) {
      if (this.searchEntryVisible) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Image($r('app.media.dock_search')).width(20).height(20)
            .fillColor($r('app.color.text_secondary')).accessibilityLevel('no')
          Text('找找你的物品').fontSize(15).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          Text('名称 / 条码').fontSize(11).fontColor($r('app.color.text_tertiary'))
        }.width('100%')
      }
        .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .width('100%').height(54).padding({ left: 18, right: 18 }).borderRadius(16)
      .backgroundColor($r('app.color.surface_card'))
      .accessibilityText('搜索物品名称或条码')
      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
      .geometryTransition(this.reduceAnimation ? '' : 'itemtrace-home-search')
      .onClick(() => this.openSearch())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private hero() {
    Column({ space: 22 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ui_check')).width(20).height(20)
          .fillColor($r('app.color.hero_action')).accessibilityLevel('no')
        Column({ space: 5 }) {
          Text(this.dueSoonCount + this.outOfStockCount === 0 ? '生活，有条不紊。' : '有些物品，需要留意。')
            .fontSize(19).fontWeight(FontWeight.Medium).fontColor($r('app.color.hero_text'))
          Text(this.dueSoonCount + this.outOfStockCount === 0 ? '到期与补货，我们帮你记着。' : '到期与库存信息，已为你整理好。')
            .fontSize(12).fontColor($r('app.color.hero_secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      Row() {
        this.attentionMetric({ count: this.dueSoonCount, label: '到期待处理', icon: $r('app.media.ui_clock') })
        Divider().vertical(true).height(42).color($r('app.color.hero_line')).margin({ left: 12, right: 20 })
        this.attentionMetric({ count: this.outOfStockCount, label: '需要补货', icon: $r('app.media.ui_box') })
      }.width('100%')
    }
    .width('100%').alignItems(HorizontalAlign.Start).padding(24)
    .borderRadius(22).backgroundColor($r('app.color.hero_start'))
  }

  @Builder
  private attentionMetric($$: AttentionMetricParams) {
    Column({ space: 8 }) {
      Row({ space: 5 }) {
        Text($$.count.toString()).contentTransition(numericMotion(this.reduceAnimation, $$.count)).fontSize(34).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.hero_text'))
        Text('项').fontSize(12).fontColor($r('app.color.hero_secondary')).margin({ top: 12 })
      }
      Row({ space: 6 }) {
        Image($$.icon).width(14).height(14).fillColor($r('app.color.hero_secondary')).accessibilityLevel('no')
        Text($$.label).fontSize(12).fontColor($r('app.color.hero_secondary'))
      }
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private locationShortcutSection() {
    Column({ space: 14 }) {
      Row() {
        Text('按位置找').fontSize($r('app.float.font_section')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button('管理位置')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).fontSize(12).fontColor($r('app.color.text_secondary'))
          .height(44).backgroundColor(Color.Transparent).padding(0)
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LOCATION_MANAGEMENT }))
      }.width('100%')
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.locationPaths, (location: string) => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 14 }) {
                Image($r('app.media.ui_location')).width(24).height(24)
                  .fillColor($r('app.color.brand_primary')).accessibilityLevel('no')
                Text(location).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary')).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }.alignItems(HorizontalAlign.Start).width('100%')
            }
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .width(130).constraintSize({ minHeight: 110 }).padding(16).borderRadius(18)
            .backgroundColor($r('app.color.surface_card')).accessibilityText(`查看${location}的物品`)
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.openLocationList(location))
          }, (location: string) => location)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
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
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`${$$.expandableExpiry ? this.dueSoonCount : $$.items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        if ($$.expandableExpiry && this.expiryAttentionItems.length > 10) {
          Button(this.showAllExpiryItems ? '收起' : '查看全部待处理')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_accent'))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.9), () => {
              this.showAllExpiryItems = !this.showAllExpiryItems;
            }))
        }
      }
      if ($$.items.length === 0) {
        if ($$.title === '最近添加') {
          EmptyState({ title: '给物品一个位置', description: '从一件常用物品开始，记录它放在哪里。',
            actionText: '记录第一件物品', actionRoute: RouteName.ITEM_FORM,
            actionMode: 'create', actionReturnTo: RouteName.HOME })
        } else {
          Row({ space: 10 }) {
            Image($r('app.media.ui_check')).width(18).height(18)
              .fillColor($r('app.color.status_success')).accessibilityLevel('no')
            Text($$.emptyText).fontSize(13).fontColor($r('app.color.text_secondary'))
          }.width('100%').padding(18).borderRadius(16).backgroundColor($r('app.color.surface_card'))
        }
      } else {
        ForEach($$.items, (item: ItemSummary) => {
          ItemCard({ item: $$.items.find((current: ItemSummary) => current.id === item.id) ?? item, heroKey: $$.title })
        }, (item: ItemSummary) => item.id)
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
      Text('拥有的总量（包含借出）低于设置阈值，仅在应用内提示。')
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
          .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
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
      await AppServices.get().photos.loadThumbnails(summary.recentItems.concat(summary.expiryAttentionItems, summary.outOfStockItems));
      if (loadId !== this.summaryLoadId) { return; }
      this.recentItems = summary.recentItems;
      this.dueSoonItems = summary.dueSoonItems;
      this.expiryAttentionItems = summary.expiryAttentionItems;
      this.outOfStockItems = summary.outOfStockItems;
      if (this.reduceAnimation) {
        this.dueSoonCount = summary.dueSoonCount;
        this.outOfStockCount = summary.outOfStockCount;
      } else {
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.76), () => {
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

}
