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
  private query: ItemQuery = new ItemQuery();
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
      Column({ space: $r('app.float.space_3') }) {
        Row() {
          Column({ space: $r('app.float.space_1') }) {
            Text('全部物品')
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.query.isEmpty() ? this.sortDescription : '正在显示已筛选的物品')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          Button('筛选')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_control'))
            .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SEARCH, params: { query: this.query } }))
        }
        Button('+ 新增物品')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .width('100%')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create', returnTo: RouteName.ITEM_LIST } }))
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

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
              .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4') })
            }
          }
          .width('100%')
          .padding({ bottom: dockContentInset(this.dockVisible, this.keyboardVisible) })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 12 }) {
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
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4') })
      }

    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
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
    this.query.clear();
    this.loadItemsForCurrentRevision(true);
  }

  private async applyDefaultSort(items: ItemSummary[]): Promise<ItemSummary[]> {
    const preferencesResult = await AppServices.get().preferences.get();
    if (!preferencesResult.ok) {
      return items;
    }
    const sortedItems = items.slice();
    const sortMode = preferencesResult.getData().defaultSort;
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
