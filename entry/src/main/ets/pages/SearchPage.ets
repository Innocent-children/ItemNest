import { router } from '@kit.ArkUI';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { Category } from '../model/Category';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { ItemListRouteParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct SearchPage {
  @State private name: string = '';
  @State private selectedLocation: string = '';
  @State private selectedCategory: string = '';
  @State private locationPaths: string[] = [];
  @State private categories: Category[] = [];
  @State private items: ItemSummary[] = [];
  @State private loading: boolean = true;
  @State private searched: boolean = false;
  @State private errorMessage: string = '';

  aboutToAppear(): void {
    this.readInitialQuery();
    this.loadFilterOptions();
  }

  build() {
    Column() {
      Row() {
        Text('搜索与筛选')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('清除')
          .onClick(() => this.clearQuery())
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column({ space: 16 }) {
          TextInput({ text: this.name, placeholder: '按物品名称搜索' })
            .onChange((value: string) => this.name = value)

          Text('位置筛选（仅显示已记录的位置）')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.locationPaths, (location: string) => {
              Button(location)
                .type(this.selectedLocation === location ? ButtonType.Capsule : ButtonType.Normal)
                .fontSize(13)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.selectedLocation = this.selectedLocation === location ? '' : location)
            }, (location: string) => location)
          }

          Text('分类筛选')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.categories, (category: Category) => {
              Button(category)
                .type(this.selectedCategory === category ? ButtonType.Capsule : ButtonType.Normal)
                .fontSize(13)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.selectedCategory = this.selectedCategory === category ? '' : category)
            }, (category: Category) => category)
          }

          Button('应用搜索与筛选')
            .width('100%')
            .onClick(() => this.search())

          if (this.loading) {
            LoadingState({ text: '正在读取筛选条件…' })
          } else if (this.errorMessage.length > 0) {
            ErrorState({ message: this.errorMessage })
            Button('重试')
              .onClick(() => this.search())
          } else if (this.searched && this.items.length === 0) {
            EmptyState({ title: '暂无搜索结果', description: '请修改或清除筛选条件后重试。' })
          } else if (this.searched) {
            Text(`找到 ${this.items.length} 个物品`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Button('在列表中查看结果')
              .width('100%')
              .onClick(() => router.pushUrl({ url: RouteName.ITEM_LIST, params: { query: this.currentQuery() } }))
            ForEach(this.items, (item: ItemSummary) => {
              ItemCard({ item: item })
            }, (item: ItemSummary) => item.id)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  private readInitialQuery(): void {
    const params = router.getParams() as ItemListRouteParams;
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
      } else {
        this.errorMessage = result.getError().message;
      }
    } catch (_) {
      this.errorMessage = '查询物品失败，请重试';
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

}
