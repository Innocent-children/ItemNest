import { uiSpring } from '../ui/VisualStyle';
import { LocationRecord } from '../model/Location';
import { buildLocationSuggestions, LocationSuggestions } from '../service/LocationSuggestions';
import { LocationSelector } from './LocationSelector';

@Component
export struct LocationInput {
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @Link locationPath: string;
  @Prop locations: LocationRecord[] = [];
  @Prop inputEnabled: boolean = true;
  @Prop loadError: string = '';
  @State private showPresets: boolean = false;
  onRetry: () => void = () => {};

  private suggestions(): LocationSuggestions {
    return buildLocationSuggestions(this.locations, this.locationPath);
  }

  build() {
    Column({ space: $r('app.float.space_2') }) {
      TextInput({ text: this.locationPath, placeholder: '例如：厨房 / 冰箱 / 冷藏层' })
        .enabled(this.inputEnabled)
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .borderWidth(1)
        .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'locationPath'))
        .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
          if (this.focusedField === 'locationPath') { this.focusedField = ''; }
        }))
        .maxLength(200)
        .height(52)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius($r('app.float.radius_control'))
        .accessibilityText('存放位置，可手动输入或选择候选位置，可选')
        .borderColor(this.focusedField === 'locationPath' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
        .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
        .onChange((value: string) => this.locationPath = value)
        .onSubmit(() => this.locationPath = this.locationPath.trim())
      this.suggestionContent()
      if (this.loadError.length > 0) {
        Text(this.loadError).fontSize($r('app.float.font_caption')).fontColor($r('app.color.text_secondary'))
        Button('重新读取历史位置').enabled(this.inputEnabled).onClick(() => this.onRetry())
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private suggestionContent() {
    if (this.suggestions().recentPaths.length > 0) {
      this.suggestionTitle('最近使用')
      LocationSelector({ selectedPath: $locationPath, paths: this.suggestions().recentPaths,
        inputEnabled: this.inputEnabled })
    }
    if (this.suggestions().savedPaths.length > 0) {
      this.suggestionTitle('已保存位置')
      LocationSelector({ selectedPath: $locationPath, paths: this.suggestions().savedPaths,
        inputEnabled: this.inputEnabled })
    }
    if (this.suggestions().presetPaths.length > 0) {
      if (this.suggestions().hasHistory && this.locationPath.trim().length === 0) {
        Button(this.showPresets ? '常见位置 ▴' : '常见位置 ▾')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_secondary'))
          .fontSize($r('app.float.font_caption'))
          .constraintSize({ minHeight: 44 })
          .enabled(this.inputEnabled)
          .onClick(() => this.showPresets = !this.showPresets)
      } else {
        this.suggestionTitle('常见位置')
      }
      if (!this.suggestions().hasHistory || this.showPresets || this.locationPath.trim().length > 0) {
        LocationSelector({ selectedPath: $locationPath, paths: this.suggestions().presetPaths,
          inputEnabled: this.inputEnabled })
      }
    }
    if (this.locationPath.trim().length > 0 && this.suggestions().recentPaths.length === 0 &&
      this.suggestions().savedPaths.length === 0 && this.suggestions().presetPaths.length === 0) {
      Text('没有匹配的位置，可以继续手动填写。')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
    }
  }

  @Builder
  private suggestionTitle(title: string) {
    Text(title)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .margin({ top: $r('app.float.space_2') })
  }
}
