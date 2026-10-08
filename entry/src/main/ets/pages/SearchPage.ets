import { SearchResult } from '../service/ItemSearchService';
import { Result, success } from '../common/Result';
import { ExternalRequestParser } from '../navigation/ExternalRequestParser';
import { ExternalNavigation } from '../navigation/ExternalNavigation';
import { NavigationRouteParams } from '../navigation/RouteContract';
import { PageHeader } from '../components/PageHeader';
import { SharedSearchField } from '../components/SharedSearchField';
import { RoundedButtonStyle, dockContentInset, uiSpring, nativeTitleOptions, nativeSheetOptions } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { SearchRequestCoordinator } from '../common/SearchRequestCoordinator';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { SearchHistory } from '../model/SearchHistory';
import { ItemListRouteParams } from '../navigation/RouteContract';
import { AppServices } from '../service/AppServices';

interface SearchConditionParams {
  label: string;
  type: string;
}

@Component
export struct SearchPage {
  @State private scanning: boolean = false;
  @State private filterNotice: string = '';
  private focusOnShown: boolean = false;
  private pageVisible: boolean = false;
  private pageScroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  @State private viewportWidth: number = 360;
  @Prop isMainTab: boolean = false;
  @Prop @Watch('onTabVisibilityChanged') active: boolean = true;
  @Prop requestedQuery: ItemQuery | undefined = undefined;
  @Prop @Watch('onSearchRequested') requestRevision: number = 0;
  @State private draftLocation: string = '';
  @State private draftCategory: string = '';
  @State private showFilters: boolean = false;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemnest.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemnest.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemnest.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemnest.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemnest.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemnest.safeAreaRight') private safeAreaRight: number = 0;
  @State private name: string = '';
  @State private selectedLocation: string = '';
  @State private selectedCategory: string = '';
  @State private locationPaths: string[] = [];
  @State private categories: string[] = [];
  @State private items: ItemSummary[] = [];
  @State private suggestions: string[] = [];
  @State private history: SearchHistory[] = [];
  @State private filterLoading: boolean = false;
  @State private searchLoading: boolean = false;
  @State private includePhotos: boolean = false;
  @State private photoNotice: string = '';
  @State private searched: boolean = false;
  @State private filterErrorMessage: string = '';
  @State private searchErrorMessage: string = '';
  private requestCoordinator: SearchRequestCoordinator = new SearchRequestCoordinator();
  private inputSearchVersion: number = 0;
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.readInitialQuery();
    this.focusOnShown = this.isMainTab && this.requestRevision > 0;
    if (this.isMainTab && this.requestedQuery !== undefined) { this.applyRequestedQuery(); }
    const hasInitialQuery = !this.currentQuery().isEmpty();
    this.loadSearchDataForCurrentRevision(!hasInitialQuery, false);
    if (hasInitialQuery) {
      this.search(true, false);
    }
  }

  onPageShow(): void {
    this.refreshForRevisionChange(false);
  }

  aboutToDisappear(): void {
    this.inputSearchVersion++;
    this.requestCoordinator.invalidateQueryRequests();
  }

  private applyRequestedQuery(): void {
    if (this.requestedQuery === undefined) { return; }
    this.name = this.requestedQuery.name;
    this.selectedLocation = this.requestedQuery.locationPath ?? '';
    this.selectedCategory = this.requestedQuery.category ?? '';
  }

  private onSearchRequested(): void {
    if (!this.isMainTab || this.requestRevision === 0) { return; }
    this.inputSearchVersion++;
    this.requestCoordinator.invalidateQueryRequests();
    this.applyRequestedQuery();
    if (this.requestedQuery !== undefined) { this.search(true, false, true); }
    this.focusOnShown = true;
    if (this.pageVisible) { this.focusSearch(); }
  }

  private focusSearch(): void {
    if (!this.focusOnShown) { return; }
    try {
      this.getUIContext().getFocusController().requestFocus(this.isMainTab ? 'itemnest-tab-search-input' : 'itemnest-search-input');
      this.focusOnShown = false;
    } catch (_) {}
  }

  private onTabVisibilityChanged(): void {
    if (!this.active) {
      this.searchController.stopEditing();
      this.pageVisible = false;
      this.focusOnShown = false;
    }
  }

  private onDataRevisionChanged(): void {
    this.refreshForRevisionChange(false);
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    if (dataRevision === this.lastHandledDataRevision) {
      return false;
    }
    this.loadSearchDataForCurrentRevision(showLoading, true);
    return true;
  }

  private loadSearchDataForCurrentRevision(showLoading: boolean = true, refreshResultsIfSearched: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadFilterOptions(showLoading);
    this.loadSuggestions();
    if (refreshResultsIfSearched && this.searched) {
      this.refreshResults(false);
    }
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
      .onShown(() => this.focusSearch())
      .onHidden(() => this.searchController.stopEditing())
      .onBackPressed(() => NavigationHelper.handleBackPressed())
    }
  }

  private openFilters(): void {
    this.searchController.stopEditing();
    this.draftLocation = this.selectedLocation;
    this.draftCategory = this.selectedCategory;
    this.showFilters = true;
  }

  private currentItem(itemId: string, fallback: ItemSummary): ItemSummary {
    return this.items.find((current: ItemSummary) => current.id === itemId) ?? fallback;
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: '查找物品', subtitle: '知道放在哪里，就少一点寻找。',
        eyebrow: this.isMainTab ? 'FIND YOUR THINGS' : '', showBack: !this.isMainTab,
        actionText: '筛选位置与分类', actionIcon: $r('app.media.ui_filter'),
        onAction: () => this.openFilters(), onBack: () => {
          this.searchController.stopEditing();
          if (!NavigationHelper.handleBackPressed()) { NavigationHelper.back(); }
        } })
  }

  @Builder
  private pageContent() {
    Column() {

      Row({ space: 10 }) {
        SharedSearchField({ value: this.name, controller: this.searchController,
          inputId: this.isMainTab ? 'itemnest-tab-search-input' : 'itemnest-search-input',
          placeholder: this.includePhotos ? '名称或外观，例如：红色盒子' : '物品名称或条码',
          onChange: (value: string) => {
            this.name = value;
            this.requestCoordinator.invalidateSearchResults();
            this.searchLoading = false;
            this.searchErrorMessage = '';
            this.loadSuggestions();
            this.scheduleSearch();
          }, onSubmit: () => this.search(true) }).layoutWeight(1)
      }.width('100%').height(68).constraintSize({ maxWidth: 960 })
        .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: 12 })
        .onVisibleAreaChange([0.5], (visible: boolean) => { this.pageVisible = visible; if (visible) { this.focusSearch(); } })
      Row({ space: 12 }) {
        Button(this.scanning ? '正在扫码…' : '扫码查找').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .fontSize(13).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .enabled(!this.scanning).onClick(() => this.scanToSearch())
        Button('位置与分类').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .fontSize(13).fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
          .onClick(() => this.openFilters())
      }.width('100%').constraintSize({ maxWidth: 960 })
        .padding({ left: 24, right: 24, bottom: 12 })
      Row({ space: 12 }) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.includePhotos }).accessibilityText('同时按照片外观查找')
          .onChange((value: boolean) => { this.includePhotos = value; this.search(true, false); })
        Text('同时按照片外观查找').fontSize(14).fontColor($r('app.color.text_secondary'))
      }.width('100%').constraintSize({ maxWidth: 960 }).padding({ left: 24, right: 24, bottom: 8 })
      if (this.includePhotos) {
        Text('输入颜色或形状等描述，查找已保存的照片，例如“黑色遥控器”。')
          .fontSize(12).fontColor($r('app.color.text_secondary')).padding({ left: 24, right: 24, bottom: 8 })
      }
      if (this.photoNotice.length > 0) {
        Text(this.photoNotice).fontSize(12).fontColor($r('app.color.text_secondary')).padding({ left: 24, right: 24 })
      }
      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          if (this.filterNotice.length > 0) { Text(this.filterNotice).fontSize(12).fontColor($r('app.color.text_secondary')) }
          if (this.selectedLocation.length > 0 || this.selectedCategory.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              if (this.selectedLocation.length > 0) {
                this.conditionChip({ label: this.selectedLocation, type: 'location' })
              }
              if (this.selectedCategory.length > 0) {
                this.conditionChip({ label: this.selectedCategory, type: 'category' })
              }
            }.width('100%')
          }
          if (this.searchLoading) {
            LoadingState({ text: '正在查找…' })
          } else if (this.searchErrorMessage.length > 0) {
            ErrorState({ message: this.searchErrorMessage })
            Button('重新查找').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => this.search(true, false))
          } else if (this.searched) {
            Row() {
              Text(`${this.items.length} 件物品`).fontSize(13).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary')).layoutWeight(1)
              Button('清除条件')
                .attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).fontSize(12).height(44).padding(0)
                .fontColor($r('app.color.brand_primary')).backgroundColor(Color.Transparent)
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onClick(() => this.clearQuery())
            }.width('100%')
            if (this.items.length === 0) {
              if (this.currentQuery().isEmpty()) {
                EmptyState({ title: '还没有物品', description: '从一件常用物品开始，记下它的位置。',
                  actionText: '记录第一件物品', actionRoute: RouteName.ITEM_FORM,
                  actionMode: 'create', actionReturnTo: RouteName.SEARCH })
              } else {
                EmptyState({ title: '还没有找到', description: '试试更短的名称，或移除位置和分类条件。' })
              }
            } else {
              ForEach(this.items, (item: ItemSummary) => {
                ItemCard({ item: this.currentItem(item.id, item), heroKey: this.isMainTab ? 'tab-search' : 'search' })
              }, (item: ItemSummary) => item.id)
            }
          } else {
            if (this.suggestions.length > 0 || this.history.length > 0) {
              this.suggestionPanel()
            }
            if (this.filterLoading) {
              LoadingState({ text: '正在整理位置与分类…' })
            } else if (this.filterErrorMessage.length > 0) {
              ErrorState({ message: this.filterErrorMessage })
              Button('重试读取').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onClick(() => this.loadFilterOptions(true))
            } else {
              Column({ space: 16 }) {
                Image($r('app.media.ui_collection')).width(160).height(128).accessibilityLevel('no')
                Text('想找的，都在这里。').fontSize(19).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text('输入名称，或按位置和分类缩小范围。').fontSize(13)
                  .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
                Button('按位置与分类查找').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
                  .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                  .onClick(() => this.openFilters())
              }.width('100%').padding({ top: 36, bottom: 24 })
            }
          }
        }.width('100%').constraintSize({ maxWidth: 960 }).alignItems(HorizontalAlign.Start)
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'),
            bottom: dockContentInset(this.isMainTab, this.keyboardVisible, this.safeAreaBottom) })
      }.clip(false).align(Alignment.TopStart).width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .padding({ left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showFilters, this.filterSheet(), nativeSheetOptions({
      height: SheetSize.LARGE, detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      dragBar: true, showClose: true, title: { title: '缩小查找范围', subtitle: '按位置与分类组合查找' },
      backgroundColor: $r('app.color.surface_app'), preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined
    }, this.reduceAnimation))
  }

  @Builder
  private filterSheet() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          if (this.filterLoading) {
            LoadingState({ text: '正在读取筛选条件…' })
          } else if (this.filterErrorMessage.length > 0) {
            ErrorState({ message: this.filterErrorMessage })
            Button('重试读取').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => this.loadFilterOptions(true))
          } else {
            if (this.locationPaths.length === 0 && this.categories.length === 0) {
              Text('还没有物品填写位置或分类。为物品补充信息后，就能在这里筛选。')
                .fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            Text('存放位置').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            Flex({ wrap: FlexWrap.Wrap }) {
              this.filterChoice('全部位置', '', 'location')
              ForEach(this.locationPaths, (value: string) => {
                this.filterChoice(value, value, 'location')
              }, (value: string) => value)
            }.width('100%')
            Text('物品分类').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            Flex({ wrap: FlexWrap.Wrap }) {
              this.filterChoice('全部分类', '', 'category')
              ForEach(this.categories, (value: string) => {
                this.filterChoice(value, value, 'category')
              }, (value: string) => value)
            }.width('100%')
          }
        }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).width('100%').layoutWeight(1)
      Row() {
        Button('查看结果').attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .width('100%').height(50).fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .enabled(!this.filterLoading && this.filterErrorMessage.length === 0)
          .onClick(() => {
            this.selectedLocation = this.draftLocation;
            this.selectedCategory = this.draftCategory;
            this.showFilters = false;
            this.inputSearchVersion++;
            this.search(true, true, true);
          })
      }.width('100%').padding({ left: 24, right: 24, bottom: 24 })
    }.width('100%').height('100%')
  }

  @Builder
  private filterChoice(label: string, value: string, type: string) {
    Button(label).attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .fontSize(13).borderRadius(24)
      .fontColor((type === 'location' ? this.draftLocation : this.draftCategory) === value
        ? $r('app.color.brand_on_primary') : $r('app.color.text_primary'))
      .backgroundColor((type === 'location' ? this.draftLocation : this.draftCategory) === value
        ? $r('app.color.brand_primary') : $r('app.color.surface_card'))
      .margin({ right: 8, bottom: 8 })
      .accessibilitySelected((type === 'location' ? this.draftLocation : this.draftCategory) === value)
      .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
      .onClick(() => {
        if (type === 'location') { this.draftLocation = value; } else { this.draftCategory = value; }
      })
  }

  @Builder
  private suggestionPanel() {
    Column({ space: $r('app.float.space_2') }) {
      if (this.suggestions.length > 0) {
        Text('建议')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.suggestions, (suggestion: string) => {
            Button(suggestion)
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .type(ButtonType.Capsule)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .fontSize($r('app.float.font_caption'))
              .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
              .onClick(() => {
                this.name = suggestion;
                this.inputSearchVersion++;
                this.requestCoordinator.invalidateSuggestions();
                this.search(false, false);
              })
          }, (suggestion: string) => suggestion)
        }
      }
      if (this.history.length > 0) {
        Row() {
          Text('最近搜索')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
          Button('清除')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_app'))
            .onClick(() => this.clearHistory())
        }
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.history, (record: SearchHistory) => {
            Button(record.queryText ?? record.locationPath ?? record.category ?? '最近查看')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .type(ButtonType.Capsule)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .fontSize($r('app.float.font_caption'))
              .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
              .onClick(() => this.applyHistory(record))
          }, (record: SearchHistory) => record.id)
        }.width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private conditionChip($$: SearchConditionParams) {
    Button(`${$$.label}  ×`)
      .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
      .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
      .type(ButtonType.Capsule)
      .fontColor($r('app.color.brand_primary'))
      .backgroundColor($r('app.color.surface_accent'))
      .fontSize($r('app.float.font_caption'))
      .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
      .onClick(() => this.clearCondition($$.type))
  }

  private readInitialQuery(): void {
    try {
      const params = NavigationHelper.getParams() as ItemListRouteParams | undefined;
      const query = params?.query;
      if (query === undefined) {
        return;
      }
      this.name = query.name ?? '';
      this.selectedLocation = query.locationPath ?? '';
      this.selectedCategory = query.category ?? '';
    } catch (_) {
    }
  }

  private async loadFilterOptions(showLoading: boolean = true): Promise<void> {
    const requestId = this.requestCoordinator.beginFilterOptions();
    if (showLoading) {
      this.filterLoading = true;
      this.filterErrorMessage = '';
    }
    try {
      const result = await AppServices.get().searchItems.getFilterOptions();
      if (!this.requestCoordinator.isCurrentFilterOptions(requestId)) {
        return;
      }
      if (!result.ok) {
        if (showLoading || this.locationPaths.length + this.categories.length === 0) {
          this.filterErrorMessage = result.getError().message;
        }
        return;
      }
      this.filterErrorMessage = '';
      this.locationPaths = result.getData().locationPaths;
      this.categories = result.getData().categories;
      if (this.draftLocation.length > 0 && this.locationPaths.indexOf(this.draftLocation) < 0) { this.draftLocation = ''; }
      if (this.draftCategory.length > 0 && this.categories.indexOf(this.draftCategory) < 0) { this.draftCategory = ''; }
      if (!showLoading) {
        let changed = false;
        if (this.selectedLocation.length > 0 && this.locationPaths.indexOf(this.selectedLocation) < 0) {
          this.selectedLocation = ''; changed = true;
        }
        if (this.selectedCategory.length > 0 && this.categories.indexOf(this.selectedCategory) < 0) {
          this.selectedCategory = ''; changed = true;
        }
        if (changed) {
          this.filterNotice = '位置或分类已变动，已移除不可用的筛选条件。';
          this.search(false, false, true);
        }
      }
    } catch (_) {
      if (this.requestCoordinator.isCurrentFilterOptions(requestId) &&
        (showLoading || this.locationPaths.length + this.categories.length === 0)) {
        this.filterErrorMessage = '读取筛选条件失败，请重试';
      }
    } finally {
      if (this.requestCoordinator.isCurrentFilterOptions(requestId)) {
        this.filterLoading = false;
      }
    }
  }

  private async search(showLoading: boolean = true, recordHistory: boolean = true, allowEmpty: boolean = false): Promise<void> {
    const query = this.currentQuery();
    if (query.isEmpty() && !this.searched && !allowEmpty) {
      this.requestCoordinator.invalidateSearchResults();
      this.items = [];
      this.searched = false;
      this.searchErrorMessage = '';
      this.searchLoading = false;
      return;
    }
    const requestId = this.requestCoordinator.beginSearch();
    this.searched = true;
    this.searchLoading = showLoading;
    this.searchErrorMessage = '';
    try {
      const result = await this.queryItems(query);
      if (!this.requestCoordinator.isCurrentSearch(requestId)) {
        return;
      }
      if (result.ok) {
        this.photoNotice = result.getData().photoNotice;
        const items = result.getData().items;
        await AppServices.get().photos.loadThumbnails(items);
        if (!this.requestCoordinator.isCurrentSearch(requestId)) { return; }
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => { this.items = items; });
        this.searched = true;
        this.searchErrorMessage = '';
        if (recordHistory && !query.isEmpty()) {
          await AppServices.get().searchSuggestions.recordSearch(query);
          if (!this.requestCoordinator.isCurrentSearch(requestId)) {
            return;
          }
          await this.loadSuggestions();
        }
      } else {
        if (showLoading || this.items.length === 0) {
          this.searchErrorMessage = result.getError().message;
        }
      }
    } catch (_) {
      if (this.requestCoordinator.isCurrentSearch(requestId) && (showLoading || this.items.length === 0)) {
        this.searchErrorMessage = '查询物品失败，请重试';
      }
    } finally {
      if (this.requestCoordinator.isCurrentSearch(requestId)) {
        this.searchLoading = false;
      }
    }
  }

  private async refreshResults(showLoading: boolean = false): Promise<void> {
    const query = this.currentQuery();
    if (query.isEmpty() && !this.searched) {
      this.requestCoordinator.invalidateSearchResults();
      this.items = [];
      this.searched = false;
      this.searchErrorMessage = '';
      this.searchLoading = false;
      return;
    }
    const requestId = this.requestCoordinator.beginRefresh();
    this.searchLoading = showLoading;
    this.searchErrorMessage = '';
    try {
      const result = await this.queryItems(query);
      if (!this.requestCoordinator.isCurrentRefresh(requestId)) {
        return;
      }
      if (result.ok) {
        this.photoNotice = result.getData().photoNotice;
        const items = result.getData().items;
        await AppServices.get().photos.loadThumbnails(items);
        if (!this.requestCoordinator.isCurrentRefresh(requestId)) { return; }
        this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.4, 0.85), () => { this.items = items; });
        this.searchErrorMessage = '';
      } else {
        if (showLoading || this.items.length === 0) {
          this.searchErrorMessage = result.getError().message;
        }
      }
    } catch (_) {
      if (this.requestCoordinator.isCurrentRefresh(requestId) && (showLoading || this.items.length === 0)) {
        this.searchErrorMessage = '查询物品失败，请重试';
      }
    } finally {
      if (this.requestCoordinator.isCurrentRefresh(requestId)) {
        this.searchLoading = false;
      }
    }
  }

  private clearQuery(): void {
    this.filterNotice = "";
    this.inputSearchVersion++;
    this.requestCoordinator.invalidateQueryRequests();
    this.name = '';
    this.selectedLocation = '';
    this.selectedCategory = '';
    this.items = [];
    this.suggestions = [];
    this.searched = false;
    this.searchLoading = false;
    this.searchErrorMessage = '';
    this.photoNotice = '';
    this.loadSuggestions();
  }

  private clearCondition(type: string): void {
    if (type === 'name') {
      this.inputSearchVersion++;
      this.requestCoordinator.invalidateSuggestions();
      this.name = '';
      this.suggestions = [];
      this.loadSuggestions();
    } else if (type === 'location') {
      this.selectedLocation = '';
    } else if (type === 'category') {
      this.selectedCategory = '';
    }
    this.search(false, false);
  }

  private currentQuery(): ItemQuery {
    return new ItemQuery(
      this.name,
      this.selectedLocation.length === 0 ? undefined : this.selectedLocation,
      this.selectedCategory.length === 0 ? undefined : this.selectedCategory
    );
  }

  private async scanToSearch(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.scanning) { return; }
    this.searchController.stopEditing();
    this.scanning = true;
    try {
      const result = await AppServices.get().scan.scan(context);
      if (!result.ok) { this.searchErrorMessage = result.getError().message; return; }
      const barcode = result.getData();
      if (barcode === undefined) { return; }
      const external = ExternalRequestParser.parseUri(barcode);
      if (external !== undefined) { await ExternalNavigation.open(external); return; }
      if (barcode.length > 256) { this.searchErrorMessage = '条码内容过长，请输入物品名称查找。'; return; }
      this.inputSearchVersion++;
      this.name = barcode;
      this.selectedLocation = '';
      this.selectedCategory = '';
      await this.search(true);
    } catch (_) { this.searchErrorMessage = '扫码暂不可用，请输入物品名称或条码。'; }
    finally { this.scanning = false; }
  }

  private async loadSuggestions(): Promise<void> {
    const input = this.name;
    const requestId = this.requestCoordinator.beginSuggestion();
    try {
      const result = await AppServices.get().searchSuggestions.getSuggestions(input);
      if (!this.requestCoordinator.isCurrentSuggestion(requestId) || input !== this.name) {
        return;
      }
      if (result.ok) {
        this.suggestions = result.getData().suggestions;
        this.history = result.getData().history;
      }
    } catch (_) {
    }
  }

  private scheduleSearch(): void {
    const version = ++this.inputSearchVersion;
    setTimeout(() => {
      if (version === this.inputSearchVersion) {
        this.search(false, false);
      }
    }, 250);
  }

  private async clearHistory(): Promise<void> {
    this.requestCoordinator.invalidateSuggestions();
    try {
      const result = await AppServices.get().searchSuggestions.clearHistory();
      if (result.ok) {
        this.history = [];
      } else {
        this.searchErrorMessage = result.getError().message;
      }
    } catch (_) {
      this.searchErrorMessage = '清除搜索历史失败，请重试';
    }
  }

  private applyHistory(record: SearchHistory): void {
    this.inputSearchVersion++;
    this.requestCoordinator.invalidateSuggestions();
    this.name = record.queryText ?? '';
    this.selectedLocation = record.locationPath ?? '';
    this.selectedCategory = record.category ?? '';
    this.search(false, false);
  }


  private async queryItems(query: ItemQuery): Promise<Result<SearchResult>> {
    const result = await AppServices.get().searchItems.search(query);
    if (!result.ok || !this.includePhotos || query.name.trim().length === 0) { return result; }
    const photos = await AppServices.get().photoSearch.search(query);
    const combined = result.getData();
    if (!photos.ok) { combined.photoNotice = photos.getError().message + '；名称搜索结果仍可查看。'; return success(combined); }
    for (const item of photos.getData()) {
      if (!combined.items.some((existing: ItemSummary) => existing.id === item.id)) { item.photoMatch = true; combined.items.push(item); }
    }
    const merged = new SearchResult(query, combined.items);
    merged.photoNotice = '包含照片外观匹配的候选物品，请对照照片确认。';
    return success(merged);
  }
}
