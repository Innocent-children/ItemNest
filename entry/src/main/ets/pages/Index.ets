import { AmbientParticles } from '../components/AmbientParticles';
import { RoundedButtonStyle, dockContentInset, uiSpring } from '../ui/VisualStyle';
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
  @State private homeVisible: boolean = true;
  @State private mainTabIndex: number = 0;
  @State private navigationRootVisible: boolean = true;
  @StorageLink('itemtrace.mainDockVisible') private dockVisible: boolean = true;
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
  private animationReduceListener: (enabled: boolean) => void = (enabled: boolean) => {
    this.applyAnimationPreference(enabled);
  };

  aboutToAppear(): void {
    try {
      this.applyAnimationPreference(accessibility.isAnimationReduceEnabledSync());
      accessibility.onAnimationReduceStateChange(this.animationReduceListener);
    } catch (_) {
    }
    this.dockVisible = true;
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

  // Main columns are peers, not push/pop destinations. Their cached views and Dock stay in place.
  private selectMainTab(route: string): void {
    const index = this.mainTabRoutes.indexOf(route);
    if (index < 0 || route === this.dockRoute) {
      return;
    }
    this.mainTabIndex = index;
    this.dockRoute = route;
    if (this.pathStack.size() > 0) {
      // Leave a filtered main-column destination without replaying navigation transitions.
      this.pathStack.clear(false);
    }
    this.homeVisible = index === 0 && this.navigationRootVisible;
  }

  onBackPress(): boolean {
    if (this.pathStack.size() === 0 && this.mainTabIndex !== 0) {
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
      .hideTitleBar(true)
      .onNavBarStateChange((visible: boolean) => {
        this.navigationRootVisible = visible;
        this.homeVisible = visible && this.mainTabIndex === 0;
        if (visible) {
          this.dockVisible = true;
          this.dockRoute = this.mainTabRoutes[this.mainTabIndex];
          this.refreshSummaryForCurrentRevision(false);
        }
      })
      .navDestination(this.navDestinationBuilder)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.surface_app'))

      MainEntryBar({ activeRoute: this.dockRoute, onTabSelected: (route: string) => this.selectMainTab(route) })
        .visibility(this.dockVisible ? Visibility.Visible : Visibility.None)
        .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.dockVisible && !this.keyboardVisible ? this.safeAreaBottom : 0 })
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private mainTabs() {
    Tabs({ index: $$this.mainTabIndex }) {
      TabContent() {
        this.homeContent()
      }
      TabContent() {
        ItemListPage()
      }
      TabContent() {
        SearchPage()
      }
      TabContent() {
        SettingsPage({ isMainTab: true })
      }
    }
    .barHeight(0, true)
    .animationDuration(0)
    .scrollable(false)
    .width('100%')
    .height('100%')
    .onChange((index: number) => {
      this.mainTabIndex = index;
      if (this.navigationRootVisible) {
        this.dockRoute = this.mainTabRoutes[index];
        this.homeVisible = index === 0;
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
        Scroll() {
          Row() {
            Column({ space: $r('app.float.space_5') }) {
              this.homeHeader()
              this.hero()
              this.overview()
              if (this.locationPaths.length > 0) {
                this.locationShortcutSection()
              }
              if (shouldShowRecentSection(this.showRecentSection)) {
                this.summarySection({ title: '最近添加', subtitle: '刚记录的物品', items: this.recentItems, emptyText: '暂无物品', actionRoute: RouteName.ITEM_FORM, actionReturnTo: RouteName.HOME })
              }
              if (this.showExpirySection) {
                this.summarySection({ title: '到期待处理', subtitle: '包含已过期和即将到期，按到期日排列', items: this.showAllExpiryItems ? this.expiryAttentionItems : this.dueSoonItems, emptyText: '暂无到期待处理物品', actionRoute: RouteName.ITEM_LIST, expandableExpiry: true })
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
            .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: dockContentInset(this.dockVisible, this.keyboardVisible) })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
      }

      if (this.loading || this.errorMessage.length > 0) {
        Blank().layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, left: this.safeAreaLeft, right: this.safeAreaRight })
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
    .onWillShow(() => {
      this.dockVisible = this.mainTabRoutes.indexOf(name) >= 0;
      if (this.dockVisible) {
        this.dockRoute = name;
      }
    })
    .onBackPressed(() => NavigationHelper.handleBackPressed())
  }

  @Builder
  private homeHeader() {
    Row({ space: $r('app.float.space_3') }) {
      Column({ space: $r('app.float.space_1') }) {
        Text('首页')
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('位置、数量与到期，一目了然')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      Image($r('app.media.ui_trace'))
        .width(24).height(24)
        .fillColor($r('app.color.brand_primary'))
        .padding(12)
        .width(48).height(48)
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 0.8, color: $r('app.color.glass_border') })
        .borderRadius(24)
        .accessibilityLevel('no')
    }
    .width('100%')
  }

  @Builder
  private hero() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Stack() {
          Shape() {
            Circle().width(158).height(158)
          }
          .width(158).height(158)
          .fill(Color.Transparent).stroke($r('app.color.border_subtle')).strokeWidth(1)
          Shape() {
            Circle().width(112).height(112)
          }
          .width(112).height(112)
          .fill($r('app.color.surface_accent')).stroke($r('app.color.border_subtle')).strokeWidth(1)
          Image($r('app.media.ui_trace')).width(46).height(46)
            .fillColor($r('app.color.hero_action')).opacity(0.65)
        }
        .width(158).height(158)
      }
      .width('100%').justifyContent(FlexAlign.End)
      .padding({ top: 10, right: 10 })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')

      AmbientParticles({ active: this.homeVisible })

      Column({ space: $r('app.float.space_4') }) {
        Row({ space: $r('app.float.space_2') }) {
          Image($r('app.media.ui_trace'))
            .width(20).height(20).fillColor($r('app.color.hero_action'))
            .accessibilityLevel('no')
          Text('ITEMTRACE')
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .letterSpacing(2)
            .fontColor($r('app.color.hero_text'))
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(20)
        .backgroundColor($r('app.color.hero_chip'))

        Column({ space: 8 }) {
          Text('物品，有迹可循。')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
          Text('把位置、数量和到期日记下来；需要时，随时找到。')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.hero_secondary'))
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          Button('+ 记录物品')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .fontColor($r('app.color.hero_action_text'))
            .backgroundColor($r('app.color.hero_action'))
            .borderRadius(22)
            .padding({ left: 20, right: 20 })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create', returnTo: RouteName.HOME } }))
          Button('搜索')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .fontColor($r('app.color.hero_text'))
            .backgroundColor($r('app.color.hero_chip'))
            .borderRadius(22)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => this.selectMainTab(RouteName.SEARCH))
          Button('设置')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .fontColor($r('app.color.hero_text'))
            .backgroundColor($r('app.color.hero_chip'))
            .borderRadius(22)
            .margin({ bottom: 8 })
            .onClick(() => this.selectMainTab(RouteName.SETTINGS))
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .linearGradient({ angle: 125, colors: [[$r('app.color.hero_start'), 0], [$r('app.color.hero_end'), 1]] })
    .borderRadius($r('app.float.radius_card'))
    .clip(true)
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 6 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 18 }))
      .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
      .animation(uiSpring(this.reduceAnimation, 0.48, 0.76)))
  }

  @Builder
  private overview() {
    Row({ space: $r('app.float.space_2') }) {
      this.metricCard({ label: '最近添加', count: this.recentItems.length, background: $r('app.color.surface_accent'), textColor: $r('app.color.brand_primary') })
      this.metricCard({ label: '到期待处理', count: this.dueSoonCount, background: $r('app.color.status_warning_soft'), textColor: $r('app.color.status_warning') })
      this.metricCard({ label: '待补货', count: this.outOfStockCount, background: $r('app.color.status_danger_soft'), textColor: $r('app.color.status_danger') })
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 12 }))
      .animation(uiSpring(this.reduceAnimation, 0.42, 0.78)))
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
    .padding({ left: 14, right: 12, top: 18, bottom: 18 })
    .borderRadius(22)
    .backgroundColor($$.background)
    .shadow({ radius: 8, color: $r('app.color.shadow_soft'), offsetY: 3 })
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
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_app'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST }))
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.locationPaths, (location: string) => {
          Button(location)
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
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
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
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
        Text(`${$$.expandableExpiry ? this.dueSoonCount : $$.items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        if ($$.expandableExpiry && this.expiryAttentionItems.length > 10) {
          Button(this.showAllExpiryItems ? '收起' : '查看全部待处理')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_accent'))
            .onClick(() => this.showAllExpiryItems = !this.showAllExpiryItems)
        }
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

  private summaryEmptyDescription(title: string): string {
    if (title === '最近添加') {
      return '先记录一个物品，首页会自动显示最近内容。';
    }
    if (title === '到期待处理') {
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
