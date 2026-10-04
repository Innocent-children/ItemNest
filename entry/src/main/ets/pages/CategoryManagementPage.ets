import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { CategoryRecord } from '../model/Category';
import { AppServices } from '../service/AppServices';

@Component
export struct CategoryManagementPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private loading: boolean = true;
  @State private operating: boolean = false;
  @State private loadError: string = '';
  @State private actionError: string = '';
  @State private pressedAction: string = '';
  @State private name: string = '';
  @State private categories: CategoryRecord[] = [];
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.loadCategoriesForCurrentRevision(true);
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
    this.loadCategoriesForCurrentRevision(showLoading);
    return true;
  }

  private loadCategoriesForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadCategories(showLoading);
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
              .enabled(!this.operating)
              .onChange((value: string) => this.name = value)
            Button('新增分类')
              .width('100%')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius($r('app.float.radius_control'))
              .enabled(!this.operating)
              .scale({ x: this.pressedAction === 'create' ? 0.98 : 1, y: this.pressedAction === 'create' ? 0.98 : 1 })
              .animation({ duration: this.reduceAnimation ? 0 : 120, curve: Curve.EaseOut })
              .onTouch((event: TouchEvent) => this.updatePressedAction(event, 'create'))
              .onClick(() => this.createCategory())
            if (this.actionError.length > 0) {
              ErrorState({ message: this.actionError })
            } else if (this.loadError.length > 0) {
              ErrorState({ message: this.loadError })
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
                  .enabled(!this.operating)
                  .scale({
                    x: this.pressedAction === `toggle:${category.id}` ? 0.98 : 1,
                    y: this.pressedAction === `toggle:${category.id}` ? 0.98 : 1
                  })
                  .animation({ duration: this.reduceAnimation ? 0 : 120, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent) => this.updatePressedAction(event, `toggle:${category.id}`))
                  .onClick(() => this.toggleCategory(category))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (category: CategoryRecord) => `${category.id}:${category.updatedAt}:${category.active}`)
          }
          .width('100%')
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
    .backgroundColor($r('app.color.surface_app'))
  }

  private async loadCategories(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
      this.loadError = '';
    }
    try {
      const result = await AppServices.get().categories.list();
      if (result.ok) {
        this.categories = result.getData();
        this.loadError = '';
      } else {
        this.loadError = result.getError().message;
      }
    } catch (_) {
      this.loadError = '读取分类失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private async createCategory(): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().categories.create({ name: this.name });
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.name = '';
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadCategories(false);
      this.showToast('分类已新增');
    } catch (_) {
      this.actionError = '新增分类失败，请稍后重试';
    } finally {
      this.operating = false;
    }
  }

  private async toggleCategory(category: CategoryRecord): Promise<void> {
    if (this.operating) {
      return;
    }
    this.operating = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().categories.setActive(category.id, !category.active);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadCategories(false);
      this.showToast(category.active ? '分类已停用' : '分类已启用');
    } catch (_) {
      this.actionError = category.active ? '停用分类失败，请稍后重试' : '启用分类失败，请稍后重试';
    } finally {
      this.operating = false;
    }
  }

  private updatePressedAction(event: TouchEvent, action: string): void {
    if (event.type === TouchType.Down) {
      this.pressedAction = action;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedAction = '';
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1600
      });
    } catch (_) {
    }
  }
}
