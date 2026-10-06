import { StartupBrand } from '../components/StartupBrand';
import { KeyCode } from '@kit.InputKit';
import { SystemFeaturesPage } from './SystemFeaturesPage';
import { LocationLabelPage } from './LocationLabelPage';
import { SharePreviewPage } from './SharePreviewPage';
import { ItemActionPage } from './ItemActionPage';
import { ExternalRequest } from '../model/SystemFeatures';
import { ExternalNavigation } from '../navigation/ExternalNavigation';
import { PageHeader } from '../components/PageHeader';
import { SharedSearchField } from '../components/SharedSearchField';
import { SharedRouteMotion } from '../ui/SharedRouteMotion';
import { RoundedButtonStyle, dockBarHeight, dockContentInset, uiSpring, FloatingTabsStyle, nativeTitleOptions, numericMotion, bottomTabStyle } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { accessibility } from '@kit.AccessibilityKit';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
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
import { OutstandingLoansPage } from './OutstandingLoansPage';
import { LocationManagementPage } from './LocationManagementPage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';

interface AttentionMetricParams {
  count: number;
  label: string;
  icon: Resource;
  attention: 'expiry' | 'restock';
}

interface HomeSummarySectionParams {
  title: string;
  items: ItemSummary[];
  attention?: 'expiry' | 'restock';
}

@Entry
@Component
struct Index {
  @StorageLink('itemnest.entryError') @Watch('showEntryError') private entryError: string = '';
  @StorageLink('itemnest.externalRevision') @Watch('onExternalRequested') private externalRevision: number = 0;
  @StorageLink('itemnest.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemnest.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemnest.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private viewportWidth: number = 360;
  @State private sidebarLocation: string = '';
  @State private mainTabIndex: number = 0;
  @State private selectedTabIndex: number = 0;
  @State private navigationRootVisible: boolean = true;
  @StorageLink('itemnest.keyboardVisible') private keyboardVisible: boolean = false;
  @State private dockRoute: string = RouteName.HOME;
  private mainTabRoutes: string[] = [RouteName.HOME, RouteName.ITEM_LIST, RouteName.SEARCH, RouteName.SETTINGS];
  @State private loading: boolean = true;
  @State private initialLoadComplete: boolean = false;
  @State private totalItemCount: number = 0;
  @State private unconfiguredStockCount: number = 0;
  @State private outstandingLoanCount: number = 0;
  @State private lendingLoadFailed: boolean = false;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private expiryAttentionItems: ItemSummary[] = [];
  @State private restockItems: ItemSummary[] = [];
  @State private dueSoonCount: number = 0;
  @State private restockCount: number = 0;
  @State private locationPaths: string[] = [];
  @State private showRecentSection: boolean = true;
  @State private showExpirySection: boolean = true;
  @State private showStockSection: boolean = true;
  private dataRefreshListenerId: number = 0;
  private routeResultListenerId: number = 0;
  private externalOpening: boolean = false;
  private summaryLoadId: number = 0;
  private lastRouteRefreshAt: number = 0;
  private lastHandledDataRevision: number = -1;
  private lastHandledPreferenceRevision: number = -1;
  private pathStack: NavPathStack = new NavPathStack();
  @StorageLink('itemnest.searchSourceHidden') private searchSourceHidden: boolean = false;
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
    this.subscribeDataRefresh();
    this.subscribeRouteResultRefresh();
    this.refreshSummaryForCurrentRevision(true);
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
    SharedRouteMotion.clear();
  }

  onPageShow(): void {
    if (!this.refreshForRevisionChange(false) && !this.handleRouteRefreshParams()) {
      this.refreshSummaryForCurrentRevision(false);
    }
    this.openExternalIfRequested();
    this.showEntryError();
  }

  private showEntryError(): void {
    if (this.entryError.length === 0) { return; }
    try { this.getUIContext().getPromptAction().showToast({ message: this.entryError }); } catch (_) {}
    AppStorage.setOrCreate<string>('itemnest.entryError', '');
  }

  private onExternalRequested(): void {
    this.openExternalIfRequested();
  }

  private applyAnimationPreference(enabled: boolean): void {
    this.reduceAnimation = enabled;
    AppStorage.setOrCreate<boolean>('itemnest.reduceAnimation', enabled);
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

  private async openExternalIfRequested(): Promise<void> {
    const raw = AppStorage.get<string>('itemnest.externalRequest') ?? '';
    if (raw.length === 0 || this.externalOpening) { return; }
    this.externalOpening = true;
    try {
      const opened = await ExternalNavigation.open(JSON.parse(raw) as ExternalRequest);
      if (opened && AppStorage.get<string>('itemnest.externalRequest') === raw) {
        AppStorage.setOrCreate<string>('itemnest.externalRequest', '');
      }
    } catch (error) {
      if (AppStorage.get<string>('itemnest.externalRequest') === raw) {
        AppStorage.setOrCreate<string>('itemnest.externalRequest', '');
      }
      this.getUIContext().getPromptAction().showToast({ message: (error as Error).message || '入口暂不可用' });
    } finally { this.externalOpening = false; }
    const next = AppStorage.get<string>('itemnest.externalRequest') ?? '';
    if (next.length > 0 && next !== raw) { this.openExternalIfRequested(); }
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
      this.mainNavigation()
      if (!this.initialLoadComplete) { StartupBrand() }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.surface_app'))
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down && event.getModifierKeyState?.(['Ctrl'])) {
        if (event.keyCode === KeyCode.KEYCODE_F) { this.selectMainTab(RouteName.SEARCH); event.stopPropagation(); }
        if (event.keyCode === KeyCode.KEYCODE_N) { this.openCreateMenu(); event.stopPropagation(); }
      }
    })
  }

  @Builder
  private mainNavigation() {
    Navigation(this.pathStack) {
      this.mainTabs()
    }
    .title({ builder: this.mainHeader, height: 76 },
      nativeTitleOptions(this.reduceAnimation))
    .hideBackButton(true)
    .mode(NavigationMode.Auto)
    .navBarWidthRange(this.viewportWidth >= 1180 ? [560, 640] : [320, 420])
    .minContentWidth(420)
    .onNavBarStateChange((visible: boolean) => {
      this.navigationRootVisible = visible;
      if (visible) {
        this.dockRoute = this.mainTabRoutes[this.mainTabIndex];
        this.refreshSummaryForCurrentRevision(false);
      }
    })
    .onAppear(() => this.openExternalIfRequested())
    .navDestination(this.navDestinationBuilder)
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .customNavContentTransition((from, to, operation) =>
      this.reduceAnimation ? undefined : SharedRouteMotion.transition(from, to, operation))
    .width('100%').height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }


  private openSearch(): void {
    SharedRouteMotion.openSearch(this.getUIContext(), this.reduceAnimation);
  }

  @Builder
  private mainHeader() {
    PageHeader({ title: this.mainTabIndex === 0 ? '我的家当' : this.mainTabIndex === 1 ? '我的物品' :
      this.mainTabIndex === 2 ? '查找物品' : '我的空间',
      subtitle: this.mainTabIndex === 0 ? '你的物品，井井有条' : this.mainTabIndex === 1 ? '每一件，都好好收着。' :
        this.mainTabIndex === 2 ? '知道放在哪里，就少一点寻找。' : '让整理，更合你的习惯。',
      largeTitle: this.mainTabIndex === 0 && !this.homeScrolled,
      actionText: '记录新物品', actionIcon: $r('app.media.dock_add'),
      onAction: () => this.openCreateMenu() })
  }

  private async openCreateMenu(): Promise<void> {
    const result = await this.getUIContext().getPromptAction().showActionMenu({
      title: '记录新物品', buttons: [
        { text: '手动记录', color: $r('app.color.brand_primary') },
        { text: '扫描条码后填写', color: $r('app.color.brand_primary') },
        { text: '拍照并填写物品', color: $r('app.color.brand_primary') }
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
    Row() {
      if (this.viewportWidth >= 1180) {
        Scroll() {
          Column({ space: 10 }) {
            Text('存放位置').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            Button('全部物品').width('100%').onClick(() => { this.sidebarLocation = ''; this.selectMainTab(RouteName.ITEM_LIST); })
            ForEach(this.locationPaths, (path: string) => {
              Button(path).width('100%').height('auto').padding(12)
                .fontColor($r('app.color.brand_primary'))
                .backgroundColor(path === this.sidebarLocation ? $r('app.color.surface_accent') : Color.Transparent)
                .onClick(() => { this.sidebarLocation = path; this.selectMainTab(RouteName.ITEM_LIST); })
            }, (path: string) => path)
          }.width('100%').padding(12)
        }.width(190).height('100%')
      }
      Tabs({ index: this.mainTabIndex, controller: this.tabsController }) {
        TabContent() {
          this.homeContent()
        }.tabBar(bottomTabStyle('首页', $r('sys.symbol.house'), this.reduceAnimation))
        TabContent() {
          ItemListPage({ isMainTab: true, locationFilter: this.sidebarLocation })
        }.tabBar(bottomTabStyle('物品', $r('sys.symbol.archivebox'), this.reduceAnimation))
        TabContent() {
          SearchPage({ isMainTab: true })
        }.tabBar(bottomTabStyle('查找', $r('sys.symbol.magnifyingglass'), this.reduceAnimation))
        TabContent() {
          SettingsPage({ isMainTab: true })
        }.tabBar(bottomTabStyle('我的', $r('sys.symbol.person'), this.reduceAnimation))
      }
      .attributeModifier(new FloatingTabsStyle(this.reduceAnimation))
      .barPosition(BarPosition.End)
      .barOverlap(true)
      .barHeight(this.keyboardVisible ? 0 : dockBarHeight)
      .animationMode(AnimationMode.CONTENT_FIRST_WITH_JUMP)
      .animationCurve(Curve.Friction)
      .animationDuration(this.reduceAnimation ? 0 : 320)
      .scrollable(true)
      .layoutWeight(1)
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
        }.width('100%').height('100%')
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
              if (this.totalItemCount === 0) {
                EmptyState({ title: '先记住一件常用物品', description: '填好名称和位置，下次输入名称就能找到。',
                  actionText: '记录第一件物品', actionRoute: RouteName.ITEM_FORM,
                  actionMode: 'create', actionReturnTo: RouteName.HOME })
              } else {
                this.hero()
                if (this.showExpirySection && this.expiryAttentionItems.length > 0) {
                  this.summarySection({ title: '到期待处理', items: this.expiryAttentionItems, attention: 'expiry' })
                }
                if (this.showStockSection && this.restockItems.length > 0) {
                  this.summarySection({ title: '需要补货', items: this.restockItems, attention: 'restock' })
                }
                if (this.showStockSection && this.unconfiguredStockCount > 0) {
                  Row({ space: 8 }) {
                    Text(`${this.unconfiguredStockCount} 件物品未设置最低数量，目前仅在用完后提示补货。`)
                      .layoutWeight(1).fontSize(12).fontColor($r('app.color.text_secondary'))
                    Button('去设置').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                      .fontSize(13).fontColor($r('app.color.brand_primary')).backgroundColor(Color.Transparent)
                      .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { section: 'stock' } }))
                  }.width('100%')
                }
                Button({ type: ButtonType.Normal }) {
                  Row() {
                    Image($r('app.media.ui_lend')).width(22).height(22).fillColor($r('app.color.brand_primary'))
                    Text('借出未还').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1).margin({ left: 12 })
                    Text(this.lendingLoadFailed ? '点击重新查看' : `${this.outstandingLoanCount} 笔`)
                      .fontSize(13).fontColor($r('app.color.text_secondary'))
                    Image($r('app.media.ui_chevron')).width(14).height(14).fillColor($r('app.color.text_secondary')).margin({ left: 10 })
                  }.width('100%')
                }.attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).width('100%').padding(18)
                  .backgroundColor($r('app.color.surface_card')).borderRadius(18)
                  .onClick(() => NavigationHelper.pushUrl({ url: RouteName.OUTSTANDING_LOANS }))
                if (this.locationPaths.length > 0) { this.locationShortcutSection() }
                if (shouldShowRecentSection(this.showRecentSection) && this.recentItems.length > 0) {
                  this.summarySection({ title: '最近添加', items: this.recentItems })
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
        .align(Alignment.TopStart)
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
      if (name === RouteName.SYSTEM_FEATURES) {
        SystemFeaturesPage()
      } else if (name === RouteName.LOCATION_LABEL) {
        LocationLabelPage()
      } else if (name === RouteName.SHARE_PREVIEW) {
        SharePreviewPage()
      } else if (name === RouteName.ITEM_ACTION) {
        ItemActionPage()
      } else if (name === RouteName.ITEM_LIST) {
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
      } else if (name === RouteName.OUTSTANDING_LOANS) {
        OutstandingLoansPage()
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
    Column() {
      if (!this.searchSourceHidden) {
        SharedSearchField({ editable: false, inputId: 'itemnest-home-search-input',
          transitionId: 'itemnest-home-search', onOpen: () => this.openSearch() })
      }
    }.width('100%').height(52).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private hero() {
    Row() {
      this.attentionMetric({ count: this.dueSoonCount, label: '到期待处理', icon: $r('app.media.ui_clock'), attention: 'expiry' })
      Divider().vertical(true).height(42).color($r('app.color.hero_line')).margin({ left: 12, right: 20 })
      this.attentionMetric({ count: this.restockCount, label: '需要补货', icon: $r('app.media.ui_box'), attention: 'restock' })
    }.width('100%').padding(18).borderRadius(20).backgroundColor($r('app.color.hero_start'))
  }

  @Builder
  private attentionMetric($$: AttentionMetricParams) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Row({ space: 5 }) {
          Text($$.count.toString()).contentTransition(numericMotion(this.reduceAnimation, $$.count)).fontSize(26).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.hero_text'))
          Text('项').fontSize(12).fontColor($r('app.color.hero_secondary')).margin({ top: 12 })
        }
        Row({ space: 6 }) {
          Image($$.icon).width(14).height(14).fillColor($r('app.color.hero_secondary')).accessibilityLevel('no')
          Text($$.label).fontSize(12).fontColor($r('app.color.hero_secondary'))
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.buttonStyle(ButtonStyleMode.TEXTUAL).borderRadius(16)
      .layoutWeight(1).padding(0).backgroundColor(Color.Transparent)
      .accessibilityText(`${$$.label} ${$$.count} 项，查看列表`)
      .onClick(() => this.openAttentionList($$.attention))
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
        Text(`${$$.items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        if ($$.attention === undefined) {
          Button('全部物品').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .fontSize(12).fontColor($r('app.color.brand_primary')).backgroundColor(Color.Transparent)
            .onClick(() => this.selectMainTab(RouteName.ITEM_LIST))
        } else if ($$.items.length > 3) {
          Button('查看全部').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .fontSize(12).fontColor($r('app.color.brand_primary')).backgroundColor(Color.Transparent)
            .onClick(() => this.openAttentionList($$.attention ?? 'expiry'))
        }
      }
      ForEach($$.items.slice(0, 3), (item: ItemSummary) => {
        ItemCard({ item: $$.items.find((current: ItemSummary) => current.id === item.id) ?? item, heroKey: $$.title })
      }, (item: ItemSummary) => item.id)
    }
    .width('100%')
  }

  private openAttentionList(attention: 'expiry' | 'restock'): void {
    NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { attention: attention } });
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
        if (showLoading || this.recentItems.length + this.expiryAttentionItems.length + this.restockItems.length === 0) {
          this.errorMessage = result.getError().message;
        }
        return;
      }
      this.errorMessage = '';
      const summary = result.getData();
      await AppServices.get().photos.loadThumbnails(summary.recentItems.concat(summary.expiryAttentionItems, summary.restockItems));
      if (loadId !== this.summaryLoadId) { return; }
      this.totalItemCount = summary.totalItemCount;
      this.unconfiguredStockCount = summary.unconfiguredStockCount;
      this.recentItems = summary.recentItems.filter((item: ItemSummary) =>
        !(this.showExpirySection && summary.expiryAttentionItems.some((attention: ItemSummary) => attention.id === item.id)) &&
        !(this.showStockSection && summary.restockItems.some((attention: ItemSummary) => attention.id === item.id)));
      this.expiryAttentionItems = summary.expiryAttentionItems;
      this.restockItems = summary.restockItems;
      if (this.reduceAnimation) {
        this.dueSoonCount = summary.dueSoonCount;
        this.restockCount = summary.restockCount;
      } else {
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.76), () => {
          this.dueSoonCount = summary.dueSoonCount;
          this.restockCount = summary.restockCount;
        });
      }
      await this.loadLocationShortcuts(loadId);
      const loans = await AppServices.get().lending.getOutstandingLoans();
      if (loadId !== this.summaryLoadId) { return; }
      this.lendingLoadFailed = !loans.ok;
      if (loans.ok) { this.outstandingLoanCount = loans.getData().length; }
    } catch (_) {
      if (loadId === this.summaryLoadId && (showLoading || this.recentItems.length + this.expiryAttentionItems.length + this.restockItems.length === 0)) {
        this.errorMessage = '数据库初始化失败，请重试';
      }
    } finally {
      if (loadId === this.summaryLoadId) {
        this.loading = false;
        this.initialLoadComplete = true;
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
