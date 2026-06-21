import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { CategoryRecord } from '../model/Category';
import { AppServices } from '../service/AppServices';

@Entry
@Component
struct CategoryManagementPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private name: string = '';
  @State private categories: CategoryRecord[] = [];

  aboutToAppear(): void {
    this.loadCategories();
  }

  private onDataRevisionChanged(): void {
    this.loadCategories();
  }

  build() {
    Column() {
      Text('分类管理')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取分类…' })
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_4') }) {
            TextInput({ text: this.name, placeholder: '新增分类名称' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.name = value)
            Button('新增分类')
              .width('100%')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.createCategory())
            if (this.errorMessage.length > 0) {
              ErrorState({ message: this.errorMessage })
            }
            ForEach(this.categories, (category: CategoryRecord) => {
              Row() {
                Column({ space: $r('app.float.space_1') }) {
                  Text(category.name)
                    .fontSize($r('app.float.font_body'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(`${category.systemPreset ? '系统分类' : '自定义分类'} · ${category.active ? '可用' : '已停用'}`)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                Button(category.active ? '停用' : '启用')
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .onClick(() => this.toggleCategory(category))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (category: CategoryRecord) => category.id)
          }
          .width('100%')
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_app'))
  }

  private async loadCategories(): Promise<void> {
    this.loading = true;
    const result = await AppServices.get().categories.list();
    if (result.ok) {
      this.categories = result.getData();
      this.errorMessage = '';
    } else {
      this.errorMessage = result.getError().message;
    }
    this.loading = false;
  }

  private async createCategory(): Promise<void> {
    const result = await AppServices.get().categories.create({ name: this.name });
    if (result.ok) {
      this.name = '';
      await this.loadCategories();
      AppEventBus.notifyDataChanged();
    } else {
      this.errorMessage = result.getError().message;
    }
  }

  private async toggleCategory(category: CategoryRecord): Promise<void> {
    const result = await AppServices.get().categories.setActive(category.id, !category.active);
    if (result.ok) {
      await this.loadCategories();
      AppEventBus.notifyDataChanged();
    } else {
      this.errorMessage = result.getError().message;
    }
  }
}
