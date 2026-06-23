import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LocationRecord } from '../model/Location';
import { AppServices } from '../service/AppServices';

@Component
export struct LocationManagementPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private name: string = '';
  @State private selectedParentId: string = '';
  @State private locations: LocationRecord[] = [];
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    this.loadLocationsForCurrentRevision(true);
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
    this.loadLocationsForCurrentRevision(showLoading);
    return true;
  }

  private loadLocationsForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadLocations(showLoading);
  }

  build() {
    Column() {
      Text('位置管理')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取位置…' })
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_4') }) {
            TextInput({ text: this.name, placeholder: '新增位置名称' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.name = value)
            Flex({ wrap: FlexWrap.Wrap }) {
              Button('无父级')
                .type(ButtonType.Capsule)
                .fontColor(this.selectedParentId.length === 0 ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                .backgroundColor(this.selectedParentId.length === 0 ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                .onClick(() => this.selectedParentId = '')
              ForEach(this.locations, (location: LocationRecord) => {
                if (location.active) {
                  Button(location.path)
                    .type(ButtonType.Capsule)
                    .fontColor(this.selectedParentId === location.id ? $r('app.color.brand_on_primary') : $r('app.color.brand_primary'))
                    .backgroundColor(this.selectedParentId === location.id ? $r('app.color.brand_primary') : $r('app.color.surface_accent'))
                    .fontSize($r('app.float.font_caption'))
                    .margin({ right: $r('app.float.space_2'), bottom: $r('app.float.space_2') })
                    .onClick(() => this.selectedParentId = this.selectedParentId === location.id ? '' : location.id)
                }
              }, (location: LocationRecord) => location.id)
            }
            Button('新增位置')
              .width('100%')
              .fontColor($r('app.color.brand_on_primary'))
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius($r('app.float.radius_control'))
              .onClick(() => this.createLocation())
            if (this.errorMessage.length > 0) {
              ErrorState({ message: this.errorMessage })
            }
            ForEach(this.locations, (location: LocationRecord) => {
              Row() {
                Column({ space: $r('app.float.space_1') }) {
                  Text(location.path)
                    .fontSize($r('app.float.font_body'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(location.active ? '可用' : '已停用')
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                Button(location.active ? '停用' : '启用')
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor($r('app.color.surface_accent'))
                  .borderRadius($r('app.float.radius_control'))
                  .onClick(() => this.toggleLocation(location))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (location: LocationRecord) => location.id)
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

  private async loadLocations(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
    }
    const result = await AppServices.get().locations.list();
    if (result.ok) {
      this.locations = result.getData();
      this.errorMessage = '';
    } else {
      if (showLoading || this.locations.length === 0) {
        this.errorMessage = result.getError().message;
      }
    }
    this.loading = false;
  }

  private async createLocation(): Promise<void> {
    const result = await AppServices.get().locations.create({
      name: this.name,
      parentId: this.selectedParentId.length === 0 ? undefined : this.selectedParentId
    });
    if (result.ok) {
      this.name = '';
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadLocations(false);
      this.showToast('位置已新增');
    } else {
      this.errorMessage = result.getError().message;
    }
  }

  private async toggleLocation(location: LocationRecord): Promise<void> {
    const result = location.active ? await AppServices.get().locations.deactivate(location.id) : await AppServices.get().locations.activate(location.id);
    if (result.ok) {
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadLocations(false);
      this.showToast(location.active ? '位置已停用' : '位置已启用');
    } else {
      this.errorMessage = result.getError().message;
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
