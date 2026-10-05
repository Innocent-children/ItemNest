import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, dockContentInset, uiSpring } from '../ui/VisualStyle';
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
  @Prop isMainTab: boolean = false;
  @State private contentWidth: number = 0;
  @State private selectedSort: ItemSortMode | undefined = undefined;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.mainDockVisible') private dockVisible: boolean = true;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
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
    Column() {
      PageHeader({ title: this.query.isEmpty() ? '我的物品' : '筛选结果',
        subtitle: '每一件，都好好收着。', eyebrow: this.isMainTab ? 'YOUR COLLECTION' : '',
        showBack: !this.isMainTab, actionText: '查找与筛选', actionIcon: $r('app.media.dock_search'),
        onAction: () => NavigationHelper.pushUrl({ url: RouteName.SEARCH, params: { query: this.query } }) })
      Row() {
        Text(this.loading ? '正在整理物品' : `共 ${this.items.length} 件物品`)
          .fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button(this.sortDescription.replace('按', '').replace('排序', '') + '⌄')
          .height(44).fontSize(12).padding(0).fontColor($r('app.color.brand_primary'))
          .backgroundColor(Color.Transparent)
          .bindMenu([
            { value: '最近更新', action: () => this.changeSort(ItemSortMode.UPDATED_DESC) },
            { value: '最近添加', action: () => this.changeSort(ItemSortMode.CREATED_DESC) },
            { value: '名称 A-Z', action: () => this.changeSort(ItemSortMode.NAME_ASC) }
          ])
      }.width('100%').constraintSize({ maxWidth: 960 })
        .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: 6 })
      if (!this.query.isEmpty()) {
        Row({ space: 8 }) {
          Text([this.query.name, this.query.locationPath ?? '', this.query.category ?? ''].filter((value: string) => value.length > 0).join(' · '))
            .fontSize(12).fontColor($r('app.color.brand_primary')).layoutWeight(1)
          Button('清除').height(44).fontSize(12).fontColor($r('app.color.brand_primary'))
            .backgroundColor(Color.Transparent).onClick(() => this.handleEmptyAction())
        }.width('100%').constraintSize({ maxWidth: 960 })
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter') })
      }

      if (this.loading || this.errorMessage.length > 0 || this.items.length === 0) {
        Scroll() {
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
                if (this.query.isEmpty()) {
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
          .padding({ bottom: dockContentInset(this.dockVisible, this.keyboardVisible) })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: ItemSummary) => {
            ListItem() {
              ItemCard({ item: item })
            }
          }, (item: ItemSummary) => `${item.id}:${item.updatedAt}:${item.expiryStatus}:${item.quantity}`)
          ListItem() {
            Row().width('100%').height(dockContentInset(this.dockVisible, this.keyboardVisible))
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
    .padding({ top: this.safeAreaTop, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.contentWidth = Number(area.width))
  }

  private readQuery(): void {
    try {
      const params = NavigationHelper.getParams() as ItemListRouteParams | undefined;
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
      if (query.isEmpty()) {
        const result = await AppServices.get().listItems.listAll();
        if (!this.loadRequestCoordinator.isCurrent(requestId)) {
          return;
        }
        if (result.ok) {
          const sortedItems = await this.applyDefaultSort(result.getData());
          if (!this.loadRequestCoordinator.isCurrent(requestId)) {
            return;
          }
          this.items = sortedItems;
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
          if (!this.loadRequestCoordinator.isCurrent(requestId)) {
            return;
          }
          this.items = sortedItems;
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
    this.items = await this.applyDefaultSort(this.items);
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
