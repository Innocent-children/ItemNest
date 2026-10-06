import { AppIcon } from '../model/AppIcon';
import { AppServices } from '../service/AppServices';
import { RoundedButtonStyle } from '../ui/VisualStyle';
import { LoadingState } from './LoadingState';

@Component
export struct AppIconPicker {
  onSelected: (icon: AppIcon) => void = () => {};
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private selected: AppIcon | undefined = undefined;
  @State private current: AppIcon = AppIcon.GIRL;
  @State private loading: boolean = true;
  @State private ready: boolean = false;
  @State private supported: boolean = true;
  @State private saving: boolean = false;
  @State private errorMessage: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.ready = false;
    this.errorMessage = '';
    const result = await AppServices.get().appIcon.getState();
    this.loading = false;
    if (!result.ok) {
      this.errorMessage = result.getError().message;
      return;
    }
    const state = result.getData();
    this.supported = state.supported;
    this.current = state.current;
    this.selected = state.current;
    this.ready = true;
  }

  private async apply(): Promise<void> {
    if (this.selected === undefined || this.saving || !this.ready || !this.supported) {
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    const result = await AppServices.get().appIcon.select(this.selected);
    this.saving = false;
    if (!result.ok) {
      this.errorMessage = result.getError().message;
      const actual = await AppServices.get().appIcon.getState();
      if (actual.ok) {
        this.current = actual.getData().current;
      }
      return;
    }
    this.current = result.getData();
    this.onSelected(result.getData());
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Text('选择喜欢的图标，随时可以更换。')
          .fontSize(14).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
        if (this.loading) {
          LoadingState({ text: '正在读取应用图标…' })
        } else if (this.ready) {
          Row({ space: 14 }) {
            this.iconOption(AppIcon.GIRL, '女生形象', $r('app.media.foreground'))
            this.iconOption(AppIcon.BUDDY, '男生形象', $r('app.media.buddy_foreground'))
          }.width('100%').alignItems(VerticalAlign.Top)
          if (!this.supported) {
            Text('当前系统暂不支持更换桌面图标，升级至 HarmonyOS 7 后即可使用。')
              .fontSize(14).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
          }
        }
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage).fontSize(14).fontColor($r('app.color.status_danger'))
            .textAlign(TextAlign.Center)
        }
        if (!this.loading && !this.ready) {
          Button('重新读取').onClick(() => this.load())
        } else if (this.ready && this.supported) {
          Button(this.saving ? '正在应用…' : '使用这个图标')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .width('100%').height(52).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
            .enabled(this.selected !== undefined && !this.saving)
            .onClick(() => this.apply())
        }
      }.width('100%').constraintSize({ maxWidth: 520 }).padding(24)
    }.width('100%').height('100%')
      .align(Alignment.TopStart)
  }

  @Builder
  private iconOption(icon: AppIcon, title: string, foreground: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 14 }) {
        Image(foreground).width('100%').aspectRatio(1).objectFit(ImageFit.Contain)
          .backgroundColor('#FFF6E4').borderRadius(26).clip(true).accessibilityLevel('no')
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Text(this.selected === icon ? '已选择' : this.current === icon ? '当前使用' : '点击选择')
          .fontSize(12).fontColor(this.selected === icon ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
      }.width('100%').padding(12)
    }.attributeModifier(new RoundedButtonStyle(this.reduceAnimation)).layoutWeight(1)
      .backgroundColor(this.selected === icon ? $r('app.color.surface_accent') : $r('app.color.surface_card'))
      .border({ width: 2, color: this.selected === icon ? $r('app.color.brand_primary') : Color.Transparent })
      .borderRadius(24).clip(true)
      .enabled(!this.saving && this.supported)
      .accessibilityText(`${title}，${this.selected === icon ? '已选择' : '未选择'}`)
      .onClick(() => this.selected = icon)
  }
}
