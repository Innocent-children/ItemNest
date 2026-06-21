import { NavigationHelper } from '../navigation/NavigationHelper';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { Category } from '../model/Category';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { SearchHistory } from '../model/SearchHistory';
import { ItemListRouteParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct SearchPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private name: string = '';
  @State private selectedLocation: string = '';
  @State private selectedCategory: string = '';
  @State private locationPaths: string[] = [];
  @State private categories: Category[] = [];
  @State private items: ItemSummary[] = [];
  @State private suggestions: string[] = [];
  @State private history: SearchHistory[] = [];
  @State private loading: boolean = true;
  @State private searched: boolean = false;
  @State private errorMessage: string = '';

  aboutToAppear(): void {
    this.readInitialQuery();
    this.loadFilterOptions();
    this.loadSuggestions();
  }

  onPageShow(): void {
    this.loadFilterOptions();
    this.loadSuggestions();
    if (this.searched) {
      this.refreshResults();
    }
  }

  private onDataRevisionChanged(): void {
    this.loadFilterOptions();
    this.loadSuggestions();
    if (this.searched) {
      this.refreshResults();
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
          Text('按名称、位置和分类快速缩小范围')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Button('清除')
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
            TextInput({ text: this.name, placeholder: '输入物品名称，例如：感冒药' })
              .backgroundColor($r('app.color.surface_app'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => {
                this.name = value;
                this.loadSuggestions();
              })
            if (this.suggestions.length > 0 || this.history.length > 0) {
              this.suggestionPanel()
            }
          }
          .padding($r('app.float.space_4'))
          .borderRadius($r('app.float.radius_card'))
          .backgroundColor($r('app.color.surface_card'))

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
                  .type(ButtonType.Capsule)
                  .fontColor(this.selectedLocation === location ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                  .backgroundColor(this.selectedLocation === location ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                  .fontSize($r('app.float.font_caption'))
                  .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                  .onClick(() => this.selectedLocation = this.selectedLocation === location ? '' : location)
              }, (location: string) => location)
            }
          }
          .padding($r('app.float.space_4'))
          .borderRadius($r('app.float.radius_card'))
          .backgroundColor($r('app.color.surface_card'))

          Column({ space: $r('app.float.space_3') }) {
            Text('分类筛选')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.categories, (category: Category) => {
                Button(category)
                  .type(ButtonType.Capsule)
                  .fontColor(this.selectedCategory === category ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                  .backgroundColor(this.selectedCategory === category ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                  .fontSize($r('app.float.font_caption'))
                  .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                  .onClick(() => this.selectedCategory = this.selectedCategory === category ? '' : category)
              }, (category: Category) => category)
            }
          }
          .padding($r('app.float.space_4'))
          .borderRadius($r('app.float.radius_card'))
          .backgroundColor($r('app.color.surface_card'))

          Button('应用搜索与筛选')
            .width('100%')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius($r('app.float.radius_control'))
            .onClick(() => this.search())

          if (this.loading) {
            LoadingState({ text: '正在读取筛选条件…' })
          } else if (this.errorMessage.length > 0) {
            ErrorState({ message: this.errorMessage })
            Button('重试')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.search())
          } else if (this.searched && this.items.length === 0) {
            EmptyState({ title: '暂无搜索结果', description: '请修改或清除筛选条件后重试。' })
          } else if (this.searched) {
            Text(`找到 ${this.items.length} 个物品`)
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Button('在列表中查看结果')
              .width('100%')
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST, params: { query: this.currentQuery() } }))
            ForEach(this.items, (item: ItemSummary) => {
              ItemCard({ item: item })
            }, (item: ItemSummary) => item.id)
          }
        }
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
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
              .type(ButtonType.Capsule)
              .fontColor($r('app.color.brand_primary'))
              .backgroundColor($r('app.color.surface_accent'))
              .fontSize($r('app.float.font_caption'))
              .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
              .onClick(() => this.name = suggestion)
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
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_app'))
            .onClick(() => this.clearHistory())
        }
        ForEach(this.history, (record: SearchHistory) => {
          Button(record.queryText ?? record.locationPath ?? record.category ?? '最近查看')
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

  private readInitialQuery(): void {
    const params = NavigationHelper.getParams() as ItemListRouteParams;
    if (!params) {
      return;
    }
    const query = params.query;
    if (query !== undefined) {
      this.name = query.name;
      this.selectedLocation = query.locationPath ?? '';
      this.selectedCategory = query.category ?? '';
    }
  }

  private async loadFilterOptions(): Promise<void> {
    this.loading = true;
    const result = await AppServices.get().searchItems.getFilterOptions();
    if (!result.ok) {
      this.errorMessage = result.getError().message;
      this.loading = false;
      return;
    }
    this.locationPaths = result.getData().locationPaths;
    this.categories = result.getData().categories;
    this.loading = false;
  }

  private async search(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const query = this.currentQuery();
    try {
      const result = await AppServices.get().searchItems.search(query);
      if (result.ok) {
        this.items = result.getData().items;
        this.searched = true;
        await AppServices.get().searchSuggestions.recordSearch(query);
        await this.loadSuggestions();
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '查询物品失败，请重试';
    } finally {
      this.loading = false;
    }
  }

  private async refreshResults(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await AppServices.get().searchItems.search(this.currentQuery());
      if (result.ok) {
        this.items = result.getData().items;
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '鏌ヨ鐗╁搧澶辫触锛岃閲嶈瘯';
    } finally {
      this.loading = false;
    }
  }

  private clearQuery(): void {
    this.name = '';
    this.selectedLocation = '';
    this.selectedCategory = '';
    this.items = [];
    this.searched = false;
  }

  private currentQuery(): ItemQuery {
    return new ItemQuery(
      this.name,
      this.selectedLocation.length === 0 ? undefined : this.selectedLocation,
      this.selectedCategory.length === 0 ? undefined : this.selectedCategory as Category
    );
  }

  private async loadSuggestions(): Promise<void> {
    const result = await AppServices.get().searchSuggestions.getSuggestions(this.name);
    if (result.ok) {
      this.suggestions = result.getData().suggestions;
      this.history = result.getData().history;
    }
  }

  private async clearHistory(): Promise<void> {
    const result = await AppServices.get().searchSuggestions.clearHistory();
    if (result.ok) {
      this.history = [];
    } else {
      this.errorMessage = result.getError().message;
    }
  }

  private applyHistory(record: SearchHistory): void {
    this.name = record.queryText ?? '';
    this.selectedLocation = record.locationPath ?? '';
    this.selectedCategory = record.category ?? '';
  }

}
