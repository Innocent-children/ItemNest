import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, dockContentInset, uiSpring, nativeTitleOptions } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { ItemSortMode } from '../model/UserPreferences';
import { getUnhandledRouteRefreshAt } from '../navigation/RefreshContract';
import { ItemListRouteParams, RouteRefreshParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppEventBus } from '../common/AppEventBus';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { AppServices } from '../service/AppServices';

@Component
export struct ItemListPage {
  private pageScroller: Scroller = new Scroller();
  @State private attention: 'expiry' | 'restock' | undefined = undefined;
  @Prop isMainTab: boolean = false;
  @State private contentWidth: number = 0;
  @State private selectedSort: ItemSortMode | undefined = undefined;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private items: ItemSummary[] = [];
  @State private sortDescription: string = '按最近更新排序';
  @State private query: ItemQuery = new ItemQuery();
  private lastRouteRefreshAt: number = 0;
  private lastHandledDataRevision: number = -1;
  private lastHandledPreferenceRevision: number = -1;
  private loadRequestCoordinator: LatestRequestCoordinator = new LatestRequestCoordinator();

  aboutToAppear(): void {
    this.readQuery();
    this.loadItemsForCurrentRevision(true);
  }

  onPageShow(): void {
    if (!this.refreshForRevisionChange(false) && !this.handleRouteRefreshParams()) {
      this.loadItemsForCurrentRevision(false);
    }
  }

  private onRevisionChanged(): void {
    this.refreshForRevisionChange(false);
  }

  private handleRouteRefreshParams(): boolean {
    try {
      const params = NavigationHelper.getParams() as RouteRefreshParams | undefined;
      const refreshAt = getUnhandledRouteRefreshAt(params, this.lastRouteRefreshAt);
      if (refreshAt > 0) {
        this.lastRouteRefreshAt = refreshAt;
        this.loadItemsForCurrentRevision(false);
        return true;
      }
    } catch (_) {
    }
    return false;
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    const preferenceRevision = AppEventBus.currentPreferenceRevision();
    if (dataRevision === this.lastHandledDataRevision && preferenceRevision === this.lastHandledPreferenceRevision) {
      return false;
    }
    this.loadItemsForCurrentRevision(showLoading);
    return true;
  }

  private loadItemsForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.lastHandledPreferenceRevision = AppEventBus.currentPreferenceRevision();
    this.loadItems(showLoading);
  }

  build() {
    if (this.isMainTab) {
      this.pageContent()
    } else {
      NavDestination() {
        this.pageContent()
      }
      .title({ builder: this.pageHeader, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true)
      .bindToScrollable([this.pageScroller])
      .backgroundColor($r('app.color.surface_app'))
      .onBackPressed(() => NavigationHelper.handleBackPressed())
    }
  }

  private currentItem(itemId: string, fallback: ItemSummary): ItemSummary {
    return this.items.find((current: ItemSummary) => current.id === itemId) ?? fallback;
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: this.attention === 'expiry' ? '到期待处理' : this.attention === 'restock' ? '需要补货' : this.query.isEmpty() ? '我的物品' : '筛选结果',
        subtitle: '每一件，都好好收着。', eyebrow: this.isMainTab ? 'YOUR COLLECTION' : '',
        showBack: !this.isMainTab, actionText: this.attention === undefined ? '查找与筛选' : '查找其他物品', actionIcon: $r('app.media.dock_search'),
        onAction: () => NavigationHelper.pushUrl({ url: RouteName.SEARCH, params: { query: this.query } }) })
  }

  @Builder
  private pageContent() {
    Column() {

      Row() {
        Text(this.loading ? '正在整理物品' : `共 ${this.items.length} 件物品`)
          .fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        if (this.attention === undefined) {
          Button(this.sortDescription.replace('按', '').replace('排序', '') + '⌄')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .height(44).fontSize(12).padding(0).fontColor($r('app.color.brand_primary'))
            .backgroundColor(Color.Transparent)
            .bindMenu([
              { value: '最近更新', action: () => this.changeSort(ItemSortMode.UPDATED_DESC) },
              { value: '最近添加', action: () => this.changeSort(ItemSortMode.CREATED_DESC) },
              { value: '名称 A-Z', action: () => this.changeSort(ItemSortMode.NAME_ASC) }
            ])
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        }
      }.width('100%').constraintSize({ maxWidth: 960 })
        .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: 6 })
      if (!this.query.isEmpty()) {
        Row({ space: 8 }) {
          Text([this.query.name, this.query.locationPath ?? '', this.query.category ?? ''].filter((value: string) => value.length > 0).join(' · '))
            .fontSize(12).fontColor($r('app.color.brand_primary')).layoutWeight(1)
          Button('清除')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).height(44).fontSize(12).fontColor($r('app.color.brand_primary'))
            .backgroundColor(Color.Transparent).animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.handleEmptyAction())
        }.width('100%').constraintSize({ maxWidth: 960 })
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter') })
      }

      if (this.loading || this.errorMessage.length > 0 || this.items.length === 0) {
        Scroll(this.pageScroller) {
          Column({ space: $r('app.float.space_3') }) {
            if (this.loading) {
              LoadingState({ text: '正在加载物品…' })
            } else if (this.errorMessage.length > 0) {
              ErrorState({ message: this.errorMessage })
              Button('重试')
                .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                .fontColor($r('app.color.brand_on_primary'))
                .backgroundColor($r('app.color.brand_primary'))
                .onClick(() => this.loadItemsForCurrentRevision(true))
            } else if (this.items.length === 0) {
              Column({ space: $r('app.float.space_3') }) {
                if (this.attention !== undefined) {
                  EmptyState({ title: this.attention === 'expiry' ? '暂无到期待处理物品' : '库存充足',
                    description: '信息已更新，安心使用就好。' })
                } else if (this.query.isEmpty()) {
                  EmptyState({
                    title: '暂无物品',
                    description: '新增第一个物品，开始记录它放在哪里。',
                    actionText: '新增物品',
                    actionRoute: RouteName.ITEM_FORM,
                    actionMode: 'create',
                    actionReturnTo: RouteName.ITEM_LIST
                  })
                } else {
                  EmptyState({
                    title: '暂无搜索结果',
                    description: '请修改或清除搜索条件后重试。'
                  })
                  Button('清除条件')
                    .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                    .width('100%')
                    .fontColor($r('app.color.brand_primary'))
                    .backgroundColor($r('app.color.surface_accent'))
                    .borderRadius($r('app.float.radius_control'))
                    .onClick(() => this.handleEmptyAction())
                }
              }
              .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter') })
            }
          }
          .width('100%')
          .padding({ bottom: dockContentInset(this.isMainTab, this.keyboardVisible, this.safeAreaBottom) })
        }.clip(false)
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 10, scroller: this.pageScroller }) {
          ForEach(this.items, (item: ItemSummary) => {
            ListItem() {
              ItemCard({ item: this.currentItem(item.id, item), heroKey: this.isMainTab ? 'collection' : 'filtered' })
            }
          }, (item: ItemSummary) => item.id)
          ListItem() {
            Row().width('100%').height(dockContentInset(this.isMainTab, this.keyboardVisible, this.safeAreaBottom))
          }
          .accessibilityLevel('no')
        }
        .layoutWeight(1)
        .width('100%').constraintSize({ maxWidth: 960 })
        .lanes(this.contentWidth >= 700 ? 2 : 1, 12).scrollBar(BarState.Off)
        .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter') })
      }

    }
    .width('100%')
    .height('100%')
    .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.contentWidth = Number(area.width))
    }

  private readQuery(): void {
    try {
      const params = NavigationHelper.getParams() as ItemListRouteParams | undefined;
      this.attention = params?.attention;
      if (params === undefined || params.query === undefined) {
        this.query = new ItemQuery();
        return;
      }
      const query = params.query;
      this.query = new ItemQuery(query.name ?? '', query.locationPath, query.category);
    } catch (_) {
      this.query = new ItemQuery();
    }
  }

  private async loadItems(showLoading: boolean = true): Promise<void> {
    const requestId = this.loadRequestCoordinator.begin();
    const query = new ItemQuery(this.query.name, this.query.locationPath, this.query.category);
    if (showLoading) {
      this.loading = true;
      this.errorMessage = '';
    }
    try {
      if (this.attention !== undefined) {
        const result = await AppServices.get().homeSummary.getSummary();
        if (!this.loadRequestCoordinator.isCurrent(requestId)) { return; }
        if (!result.ok) {
          this.errorMessage = result.getError().message;
          return;
        }
        const items = this.attention === 'expiry' ? result.getData().expiryAttentionItems : result.getData().restockItems;
        await AppServices.get().photos.loadThumbnails(items);
        if (!this.loadRequestCoordinator.isCurrent(requestId)) { return; }
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => this.items = items);
        this.errorMessage = '';
      } else if (query.isEmpty()) {
        const result = await AppServices.get().listItems.listAll();
        if (!this.loadRequestCoordinator.isCurrent(requestId)) {
          return;
        }
        if (result.ok) {
          const sortedItems = await this.applyDefaultSort(result.getData());
          await AppServices.get().photos.loadThumbnails(sortedItems);
          if (!this.loadRequestCoordinator.isCurrent(requestId)) {
            return;
          }
          this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => { this.items = sortedItems; });
          this.errorMessage = '';
        } else {
          if (showLoading || this.items.length === 0) {
            this.errorMessage = result.getError().message;
          }
        }
      } else {
        const result = await AppServices.get().searchItems.search(query);
        if (!this.loadRequestCoordinator.isCurrent(requestId)) {
          return;
        }
        if (result.ok) {
          const sortedItems = await this.applyDefaultSort(result.getData().items);
          await AppServices.get().photos.loadThumbnails(sortedItems);
          if (!this.loadRequestCoordinator.isCurrent(requestId)) {
            return;
          }
          this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => { this.items = sortedItems; });
          this.errorMessage = '';
        } else {
          if (showLoading || this.items.length === 0) {
            this.errorMessage = result.getError().message;
          }
        }
      }
    } catch (_) {
      if (this.loadRequestCoordinator.isCurrent(requestId) && (showLoading || this.items.length === 0)) {
        this.errorMessage = '数据库初始化失败，请重试';
      }
    } finally {
      if (this.loadRequestCoordinator.isCurrent(requestId)) {
        this.loading = false;
      }
    }
  }

  private handleEmptyAction(): void {
    if (this.query.isEmpty()) {
      NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create', returnTo: RouteName.ITEM_LIST } });
      return;
    }
    this.query = new ItemQuery();
    this.loadItemsForCurrentRevision(true);
  }

  private async changeSort(mode: ItemSortMode): Promise<void> {
    this.selectedSort = mode;
    const items = await this.applyDefaultSort(this.items);
    this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => this.items = items);
  }

  private async applyDefaultSort(items: ItemSummary[]): Promise<ItemSummary[]> {
    let sortMode = this.selectedSort;
    if (sortMode === undefined) {
      const preferencesResult = await AppServices.get().preferences.get();
      if (!preferencesResult.ok) { return items; }
      sortMode = this.selectedSort ?? preferencesResult.getData().defaultSort;
    }
    const sortedItems = items.slice();
    this.sortDescription = sortMode === ItemSortMode.NAME_ASC ? '按名称 A-Z 排序' :
      sortMode === ItemSortMode.UPDATED_DESC ? '按最近更新排序' : '按最近添加排序';
    if (sortMode === ItemSortMode.NAME_ASC) {
      sortedItems.sort((left: ItemSummary, right: ItemSummary) => left.name.localeCompare(right.name));
    } else if (sortMode === ItemSortMode.UPDATED_DESC) {
      sortedItems.sort((left: ItemSummary, right: ItemSummary) => right.updatedAt - left.updatedAt);
    } else {
      sortedItems.sort((left: ItemSummary, right: ItemSummary) => right.createdAt - left.createdAt);
    }
    return sortedItems;
  }

}
