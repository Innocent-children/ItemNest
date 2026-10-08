import { SearchFieldStyle } from '../ui/VisualStyle';

/**
 * 首页入口和搜索页使用同一种原生 Search，共享转场期间保持图标、字体和圆角一致。
 */
@Component
export struct SharedSearchField {
  @Prop value: string = '';
  @Prop editable: boolean = true;
  @Prop inputId: string = '';
  @Prop transitionId: string = '';
  @Prop placeholder: string = '物品名称或条码';
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  controller: SearchController = new SearchController();
  onChange: (value: string) => void = (_value: string) => {};
  onSubmit: () => void = () => {};
  onOpen: () => void = () => {};

  build() {
    Stack() {
      Search({ value: this.value, placeholder: this.placeholder, controller: this.controller })
        .id(this.inputId)
        .width('100%').height(52).fontColor($r('app.color.text_primary'))
        .backgroundColor(Color.Transparent).borderRadius(16)
        .placeholderColor($r('app.color.text_secondary'))
        .searchIcon({ size: 20, color: $r('app.color.text_secondary') })
        .caretStyle({ color: $r('app.color.brand_primary') })
        .searchButton('查找', { autoDisable: true, fontColor: $r('app.color.brand_primary'), fontSize: 14 })
        .enableKeyboardOnFocus(this.editable)
        .focusable(this.editable)
        .hitTestBehavior(this.editable ? HitTestMode.Default : HitTestMode.None)
        .accessibilityLevel(this.editable ? 'auto' : 'no')
        .onChange((value: string) => this.onChange(value))
        .onSubmit(() => this.onSubmit())
    }.width('100%').height(52)
      .geometryTransition(this.reduceAnimation ? '' : this.transitionId)
      .attributeModifier(new SearchFieldStyle(this.reduceAnimation))
      .accessibilityText(this.editable ? '' : '搜索物品，按位置与分类筛选')
      .onClick(() => { if (!this.editable) { this.onOpen(); } })
  }
}
