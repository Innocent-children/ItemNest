import { router } from '@kit.ArkUI';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { ItemCard } from '../components/ItemCard';
import { LoadingState } from '../components/LoadingState';
import { ItemSummary } from '../model/Item';
import { RouteName } from '../navigation/RouteName';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct Index {
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private dueSoonItems: ItemSummary[] = [];
  @State private outOfStockItems: ItemSummary[] = [];

  aboutToAppear(): void {
    this.loadSummary();
  }

  onPageShow(): void {
    this.loadSummary();
  }

  build() {
    Column() {
      Row() {
        Text('ItemTrace')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('搜索')
          .onClick(() => router.pushUrl({ url: RouteName.SEARCH }))
        Button('新增')
          .margin({ left: 8 })
          .onClick(() => router.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } }))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.loading) {
        LoadingState({ text: '正在加载首页摘要…' })
      } else if (this.errorMessage.length > 0) {
        ErrorState({ message: this.errorMessage })
        Button('重试')
          .onClick(() => this.loadSummary())
      } else {
        Scroll() {
          Column({ space: 20 }) {
            this.summarySection('最近添加', this.recentItems, '暂无物品', RouteName.ITEM_FORM);
            this.summarySection('即将到期', this.dueSoonItems, '暂无即将到期物品', RouteName.ITEM_LIST);
            this.summarySection('待补货', this.outOfStockItems, '暂无待补货物品', RouteName.ITEM_LIST);
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  @Builder
  private summarySection(title: string, items: ItemSummary[], emptyText: string, actionRoute: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      if (items.length === 0) {
        EmptyState({
          title: emptyText,
          actionText: title === '最近添加' ? '新增物品' : '查看全部物品',
          actionRoute: actionRoute
        })
      } else {
        ForEach(items, (item: ItemSummary) => {
          ItemCard({ item: item })
        }, (item: ItemSummary) => item.id)
      }
    }
    .width('100%')
  }

  private async loadSummary(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await AppServices.get().homeSummary.getSummary();
      if (!result.ok) {
        this.errorMessage = result.getError().message;
        return;
      }
      this.recentItems = result.getData().recentItems;
      this.dueSoonItems = result.getData().dueSoonItems;
      this.outOfStockItems = result.getData().outOfStockItems;
    } catch (_) {
      this.errorMessage = '数据库初始化失败，请重试';
    } finally {
      this.loading = false;
    }
  }

}
