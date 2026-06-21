import { NavigationHelper } from '../navigation/NavigationHelper';
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
  @StorageLink('itemtrace.quickAddRequest') @Watch('onQuickAddRequested') private quickAddRequest: string = '';
  @StorageLink('itemtrace.dataRevision') @Watch('onRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.preferenceRevision') @Watch('onRevisionChanged') private preferenceRevision: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private recentItems: ItemSummary[] = [];
  @State private dueSoonItems: ItemSummary[] = [];
  @State private outOfStockItems: ItemSummary[] = [];
  @State private showRecentSection: boolean = true;
  @State private showExpirySection: boolean = true;
  @State private showStockSection: boolean = true;

  aboutToAppear(): void {
    this.loadSummary();
    this.openQuickAddIfRequested();
  }

  onPageShow(): void {
    this.loadSummary();
    this.openQuickAddIfRequested();
  }

  private onQuickAddRequested(): void {
    this.openQuickAddIfRequested();
  }

  private onRevisionChanged(): void {
    this.loadSummary();
  }

  private openQuickAddIfRequested(): void {
    if (this.quickAddRequest.length === 0) {
      return;
    }
    AppStorage.setOrCreate('itemtrace.quickAddRequest', '');
    NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } });
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingState({ text: '正在整理你的物品清单…' })
      } else if (this.errorMessage.length > 0) {
        Column({ space: $r('app.float.space_3') }) {
          ErrorState({ message: this.errorMessage })
          Button('重新加载')
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.loadSummary())
        }
        .padding($r('app.float.space_4'))
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_6') }) {
            this.hero()
            this.overview()
            this.managementEntrances()
            if (this.showRecentSection) {
              this.summarySection('最近添加', '刚记录的物品', this.recentItems, '暂无物品', RouteName.ITEM_FORM)
            }
            if (this.showExpirySection) {
              this.summarySection('即将到期', '优先处理，避免浪费', this.dueSoonItems, '暂无即将到期物品', RouteName.ITEM_LIST)
            }
            if (this.showStockSection) {
              this.summarySection('待补货', '数量为 0 的物品', this.outOfStockItems, '暂无待补货物品', RouteName.ITEM_LIST)
            }
          }
          .width('100%')
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }

  @Builder
  private hero() {
    Column({ space: $r('app.float.space_4') }) {
      Row({ space: $r('app.float.space_2') }) {
        Text('IT')
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius(16)
          .padding({ left: $r('app.float.space_2'), right: $r('app.float.space_2'), top: $r('app.float.space_1'), bottom: $r('app.float.space_1') })
        Text('ITEMTRACE')
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
      }
      Text('物品，有迹可循')
        .fontSize($r('app.float.font_display'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('把位置、数量和到期日记下来；需要时，随时找到。')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
      Row({ space: $r('app.float.space_2') }) {
        Button('+ 记录物品')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_on_primary'))
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.ITEM_FORM, params: { mode: 'create' } }))
        Button('搜索')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SEARCH }))
        Button('设置')
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.SETTINGS }))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.space_6'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 1, color: $r('app.color.border_subtle') })
  }

  @Builder
  private overview() {
    Row({ space: $r('app.float.space_2') }) {
      this.metricCard('最近添加', this.recentItems.length, $r('app.color.surface_accent'), $r('app.color.brand_primary'))
      this.metricCard('即将到期', this.dueSoonItems.length, $r('app.color.status_warning_soft'), $r('app.color.status_warning'))
      this.metricCard('待补货', this.outOfStockItems.length, $r('app.color.status_danger_soft'), $r('app.color.status_danger'))
    }
    .width('100%')
  }

  @Builder
  private managementEntrances() {
    Column({ space: $r('app.float.space_3') }) {
      Text('管理')
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Row({ space: $r('app.float.space_2') }) {
        Button('位置')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.LOCATION_MANAGEMENT }))
        Button('分类')
          .layoutWeight(1)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_accent'))
          .borderRadius($r('app.float.radius_control'))
          .onClick(() => NavigationHelper.pushUrl({ url: RouteName.CATEGORY_MANAGEMENT }))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private metricCard(label: string, count: number, background: ResourceColor, textColor: ResourceColor) {
    Column({ space: $r('app.float.space_1') }) {
      Text(count.toString())
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor(textColor)
    }
    .layoutWeight(1)
    .padding($r('app.float.space_3'))
    .borderRadius($r('app.float.radius_control'))
    .backgroundColor(background)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private summarySection(title: string, subtitle: string, items: ItemSummary[], emptyText: string, actionRoute: string) {
    Column({ space: $r('app.float.space_3') }) {
      Row() {
        Column({ space: $r('app.float.space_1') }) {
          Text(title)
            .fontSize($r('app.float.font_section'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        Text(`${items.length} 项`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (items.length === 0) {
        EmptyState({
          title: emptyText,
          actionText: title === '最近添加' ? '新增物品' : '查看全部',
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
      const preferencesResult = await AppServices.get().preferences.get();
      if (preferencesResult.ok) {
        this.showRecentSection = preferencesResult.getData().showRecentSection;
        this.showExpirySection = preferencesResult.getData().showExpirySection;
        this.showStockSection = preferencesResult.getData().showStockSection;
      }
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
