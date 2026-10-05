import { RoundedButtonStyle, dockContentInset, uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';
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
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

interface SearchConditionParams {
  label: string;
  type: string;
}

@Component
export struct SearchPage {
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.mainDockVisible') private dockVisible: boolean = true;
  @StorageLink('itemtrace.keyboardVisible') private keyboardVisible: boolean = false;
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
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
  @State private searched: boolean = false;
  @State private filterErrorMessage: string = '';
  @State private searchErrorMessage: string = '';
  private requestCoordinator: SearchRequestCoordinator = new SearchRequestCoordinator();
  private inputSearchVersion: number = 0;
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.readInitialQuery();
    const hasInitialQuery = !this.currentQuery().isEmpty();
    this.loadSearchDataForCurrentRevision(!hasInitialQuery, false);
    if (hasInitialQuery) {
      this.search(true, false);
    }
  }

  onPageShow(): void {
    this.refreshForRevisionChange(false);
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
    Column() {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text('搜索与筛选')
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('输入或点选条件后自动显示结果')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Button('清除')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => this.clearQuery())
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      Scroll() {
        Column({ space: $r('app.float.space_4') }) {
          Column({ space: $r('app.float.space_3') }) {
            Text('查找物品')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Row({ space: $r('app.float.space_2') }) {
              Image($r('app.media.dock_search'))
                .width(20).height(20)
                .fillColor($r('app.color.text_secondary'))
                .margin({ left: $r('app.float.space_4') })
                .accessibilityLevel('no')
              TextInput({ text: this.name, placeholder: '输入物品名称或条码' })
                .layoutWeight(1)
                .height(48)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_secondary'))
                .caretColor($r('app.color.brand_primary'))
                .backgroundColor(Color.Transparent)
                .border({ width: 0 })
                .padding({ left: 0, right: $r('app.float.space_4') })
                .onChange((value: string) => {
                  this.name = value;
                  this.requestCoordinator.invalidateSearchResults();
                  this.searchLoading = false;
                  this.searchErrorMessage = '';
                  this.loadSuggestions();
                  this.scheduleSearch();
                })
            }
            .width('100%')
            .backgroundColor($r('app.color.surface_app'))
            .border({ width: 0.8, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_pill'))
            if (this.suggestions.length > 0 || this.history.length > 0) {
              this.suggestionPanel()
            }
          }
          .width('100%')
          .padding($r('app.float.space_4'))
          .borderRadius($r('app.float.radius_card'))
          .backgroundColor($r('app.color.surface_card'))
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })

          if (!this.currentQuery().isEmpty()) {
            this.selectedConditionPanel()
          }

          if (this.locationPaths.length > 0) {
            Column({ space: $r('app.float.space_3') }) {
              Text('位置筛选')
                .fontSize($r('app.float.font_section'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('仅显示已记录的位置')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.locationPaths, (location: string) => {
                  Button(location)
                    .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                    .type(ButtonType.Capsule)
                    .fontColor(this.selectedLocation === location ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                    .backgroundColor(this.selectedLocation === location ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                    .fontSize($r('app.float.font_caption'))
                    .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                    .onClick(() => {
                      this.selectedLocation = this.selectedLocation === location ? '' : location;
                      this.search(false, false);
                    })
                }, (location: string) => location)
              }
            }
            .width('100%')
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))
            .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
          }

          if (this.categories.length > 0) {
            Column({ space: $r('app.float.space_3') }) {
              Text('分类筛选')
                .fontSize($r('app.float.font_section'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.categories, (category: string) => {
                  Button(category)
                    .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                    .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
                    .type(ButtonType.Capsule)
                    .fontColor(this.selectedCategory === category ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                    .backgroundColor(this.selectedCategory === category ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                    .fontSize($r('app.float.font_caption'))
                    .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                    .onClick(() => {
                      this.selectedCategory = this.selectedCategory === category ? '' : category;
                      this.search(false, false);
                    })
                }, (category: string) => category)
              }
            }
            .width('100%')
            .padding($r('app.float.space_4'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.surface_card'))
            .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetY: 4 })
          }

          if (this.filterLoading) {
            LoadingState({ text: '正在读取筛选条件…' })
          } else if (this.filterErrorMessage.length > 0) {
            ErrorState({ message: this.filterErrorMessage })
            Button('重试加载筛选条件')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.loadFilterOptions(true))
          }

          if (this.searchLoading) {
            LoadingState({ text: '正在查询物品…' })
          } else if (this.searchErrorMessage.length > 0) {
            ErrorState({ message: this.searchErrorMessage })
            Button('重试搜索')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.search(true, false))
          } else if (this.searched && this.items.length === 0) {
            EmptyState({ title: '暂无搜索结果', description: '请修改或清除筛选条件后重试。' })
            Button('清除条件')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .width('100%')
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.clearQuery())
          } else if (this.searched) {
            Text(`找到 ${this.items.length} 个物品`)
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Button('查看完整列表')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
              .width('100%')
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.openResultList())
            ForEach(this.items, (item: ItemSummary) => {
              ItemCard({ item: item })
            }, (item: ItemSummary) => `${item.id}:${item.updatedAt}:${item.expiryStatus}:${item.quantity}`)
          }
        }
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: dockContentInset(this.dockVisible, this.keyboardVisible) })
      }
      .layoutWeight(1)

    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
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
      }
    }
    .width('100%')
  }

  @Builder
  private selectedConditionPanel() {
    Column({ space: $r('app.float.space_2') }) {
      Row() {
        Text('已选条件')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Button('全部清除')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.3, 0.68))
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_app'))
          .onClick(() => this.clearQuery())
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        if (this.name.trim().length > 0) {
          this.conditionChip({ label: `名称：${this.name.trim()}`, type: 'name' })
        }
        if (this.selectedLocation.length > 0) {
          this.conditionChip({ label: `位置：${this.selectedLocation}`, type: 'location' })
        }
        if (this.selectedCategory.length > 0) {
          this.conditionChip({ label: `分类：${this.selectedCategory}`, type: 'category' })
        }
      }
    }
    .width('100%')
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor($r('app.color.surface_card'))
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

  private async search(showLoading: boolean = true, recordHistory: boolean = true): Promise<void> {
    const query = this.currentQuery();
    if (query.isEmpty()) {
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
      const result = await AppServices.get().searchItems.search(query);
      if (!this.requestCoordinator.isCurrentSearch(requestId)) {
        return;
      }
      if (result.ok) {
        this.items = result.getData().items;
        this.searched = true;
        this.searchErrorMessage = '';
        if (recordHistory) {
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
    if (query.isEmpty()) {
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
      const result = await AppServices.get().searchItems.search(query);
      if (!this.requestCoordinator.isCurrentRefresh(requestId)) {
        return;
      }
      if (result.ok) {
        this.items = result.getData().items;
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

  private openResultList(): void {
    const query = this.currentQuery();
    if (query.isEmpty()) {
      return;
    }
    AppServices.get().searchSuggestions.recordSearch(query);
    NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { query: query } });
  }

}
