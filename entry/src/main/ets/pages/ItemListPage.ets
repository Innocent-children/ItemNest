import { router } from '@kit.ArkUI';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { ItemListRouteParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct ItemListPage {
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private items: ItemSummary[] = [];
  private query: ItemQuery = new ItemQuery();

  aboutToAppear(): void {
    this.readQuery();
    this.loadItems();
  }

  onPageShow(): void {
    this.loadItems();
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
            Text(this.query.isEmpty() ? '按最近添加排序' : '正在显示已筛选的物品')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          Button('筛选')
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_control'))
            .onClick(() => router.pushUrl({ url: RouteName.SEARCH, params: { query: this.query } }))
        }
        Button('+ 新增物品')
          .width('100%')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => router.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } }))
      }
      .width('100%')
      .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在加载物品…' })
      } else if (this.errorMessage.length > 0) {
        ErrorState({ message: this.errorMessage })
        Button('重试')
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.loadItems())
      } else if (this.items.length === 0) {
        EmptyState({
          title: this.query.isEmpty() ? '暂无物品' : '暂无搜索结果',
          description: this.query.isEmpty() ? '新增第一个物品，开始记录它放在哪里。' : '请修改或清除搜索条件后重试。',
          actionText: this.query.isEmpty() ? '新增物品' : '清除条件',
          actionRoute: this.query.isEmpty() ? RouteName.ITEM_FORM : ''
        })
        if (!this.query.isEmpty()) {
          Button('清除条件')
            .fontColor($r('app.color.brand_primary'))
            .onClick(() => this.handleEmptyAction())
        }
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: ItemSummary) => {
            ListItem() {
              ItemCard({ item: item })
            }
          }, (item: ItemSummary) => item.id)
        }
        .layoutWeight(1)
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }

  private readQuery(): void {
    const params = router.getParams() as ItemListRouteParams;
    this.query = params.query ?? new ItemQuery();
  }

  private async loadItems(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      if (this.query.isEmpty()) {
        const result = await AppServices.get().listItems.listAll();
        if (result.ok) {
          this.items = result.getData();
        } else {
          this.errorMessage = result.getError().message;
        }
      } else {
        const result = await AppServices.get().searchItems.search(this.query);
        if (result.ok) {
          this.items = result.getData().items;
        } else {
          this.errorMessage = result.getError().message;
        }
      }
    } catch (_) {
      this.errorMessage = '数据库初始化失败，请重试';
    } finally {
      this.loading = false;
    }
  }

  private handleEmptyAction(): void {
    if (this.query.isEmpty()) {
      router.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } });
      return;
    }
    this.query.clear();
    this.loadItems();
  }

}
