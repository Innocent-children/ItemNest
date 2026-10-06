import { curves, uiMaterial, SymbolGlyphModifier } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

export const dockBarHeight: number = 56;

/**
 * 图标、文字和点击反馈都由原生页签绘制，避免叠加两套选中背景。
 */
export function bottomTabStyle(label: string, symbol: Resource, reduceAnimation: boolean): BottomTabBarStyle {
  return BottomTabBarStyle.of({
    normal: new SymbolGlyphModifier(symbol).fontSize(22).fontColor([$r('app.color.text_secondary')])
      .symbolEffect(new BounceSymbolEffect(), -1),
    selected: new SymbolGlyphModifier(symbol).fontSize(22).fontColor([$r('app.color.brand_primary')])
      .symbolEffect(new BounceSymbolEffect(), reduceAnimation ? -1 : 1)
  }, label)
    .layoutMode(LayoutMode.VERTICAL)
    .padding({ top: 5, bottom: 5, left: 4, right: 4 })
    .labelStyle({ font: { size: 11, weight: FontWeight.Medium },
      selectedColor: $r('app.color.brand_primary'), unselectedColor: $r('app.color.text_secondary') });
}

/**
 * 系统减少动画开启时，同时关闭弹簧效果和过渡时间。
 */
export function uiSpring(reduceAnimation: boolean, response: number = 0.38,
  damping: number = 0.82): AnimateParam {
  return reduceAnimation ? { duration: 0, curve: Curve.Linear } :
    { curve: curves.springMotion(response, damping, 0.12) };
}

export function uiReveal(reduceAnimation: boolean): TransitionEffect {
  return TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: reduceAnimation ? 0 : 24 }))
    .combine(TransitionEffect.scale({ x: reduceAnimation ? 1 : 0.96, y: reduceAnimation ? 1 : 0.96 }))
    .animation(uiSpring(reduceAnimation, 0.42, 0.82));
}

export class SearchFieldStyle implements AttributeModifier<StackAttribute> {
  private reduceAnimation: boolean;

  constructor(reduceAnimation: boolean) {
    this.reduceAnimation = reduceAnimation;
  }

  applyNormalAttribute(instance: StackAttribute): void {
    instance.borderRadius(16).backgroundColor($r('app.color.surface_card'))
      .border({ width: 1, color: $r('app.color.chrome_border') });
    instance.backgroundColor(Color.Transparent)
      .systemMaterial(immersiveMaterial(this.reduceAnimation, uiMaterial.ImmersiveStyle.REGULAR));
  }
}

/**
 * 由系统按设备算力绘制材质，并遵循减少动画设置。
 */
export function immersiveMaterial(reduceAnimation: boolean = false,
  style?: uiMaterial.ImmersiveStyle): uiMaterial.ImmersiveMaterial {
  return new uiMaterial.ImmersiveMaterial({
    style: style ?? uiMaterial.ImmersiveStyle.THIN, interactive: !reduceAnimation,
    lightEffect: reduceAnimation ? null : { color: $r('app.color.brand_primary') }
  });
}

export function nativeSheetOptions(options: SheetOptions, reduceAnimation: boolean): SheetOptions {
  options.systemMaterial = immersiveMaterial(reduceAnimation, uiMaterial.ImmersiveStyle.REGULAR);
  options.backgroundColor = Color.Transparent;
  return options;
}

export function nativeTitleOptions(reduceAnimation: boolean): NavigationTitleOptions {
  return { barStyle: BarStyle.STANDARD, backgroundColor: Color.Transparent,
    systemMaterial: immersiveMaterial(reduceAnimation),
    scrollEffectOptions: { scrollEffectType: ScrollEffectType.GRADUAL_BLUR } };
}

export function numericMotion(reduceAnimation: boolean, value?: number): ContentTransition | undefined {
  return reduceAnimation || value === undefined || !Number.isInteger(value) || value < 0 ?
    undefined : new NumericTextTransition({ enableBlur: true });
}

export class FloatingTabsStyle implements AttributeModifier<TabsAttribute> {
  private reduceAnimation: boolean;

  constructor(reduceAnimation: boolean) {
    this.reduceAnimation = reduceAnimation;
  }

  applyNormalAttribute(instance: TabsAttribute): void {
    instance.barFloatingStyle({
      barWidth: { smallBarWidth: 296, mediumBarWidth: 320, largeBarWidth: 320 },
      barSideMargin: 32, barBottomMargin: 14,
      systemMaterial: immersiveMaterial(this.reduceAnimation),
      maskColor: $r('app.color.chrome_glass'), maskHeight: 84 });
  }
}

export class MaterialButtonStyle implements AttributeModifier<ButtonAttribute> {
  private reduceAnimation: boolean;

  constructor(reduceAnimation: boolean) {
    this.reduceAnimation = reduceAnimation;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    instance.borderRadius(22).backgroundColor(Color.Transparent).scale({ x: 1, y: 1 })
      .systemMaterial(immersiveMaterial(this.reduceAnimation));
  }

  applyPressedAttribute(instance: ButtonAttribute): void {
    instance.scale({ x: 1, y: 1 });
  }
}

/**
 * 浮动页签覆盖滚动内容，末尾需要留下可完整查看最后一行的空间。
 */
export function dockContentInset(isMainTab: boolean, keyboardVisible: boolean, safeAreaBottom: number): number {
  if (keyboardVisible) {
    return 24;
  }
  return (isMainTab ? dockBarHeight + 30 : 24) + safeAreaBottom;
}

/**
 * 统一触摸尺寸与原生按压反馈，点击行为和禁用状态由页面决定。
 */
export class RoundedButtonStyle implements AttributeModifier<ButtonAttribute> {
  private reduceAnimation: boolean;

  constructor(reduceAnimation: boolean) {
    this.reduceAnimation = reduceAnimation;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    instance.borderRadius($r('app.float.radius_control'))
      .constraintSize({ minHeight: 44 })
      .fontSize($r('app.float.font_body'))
      .fontWeight(FontWeight.Medium)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE).buildEffect())
      .scale({ x: 1, y: 1 });
  }

  applyPressedAttribute(instance: ButtonAttribute): void {
    instance.scale({ x: this.reduceAnimation ? 1 : 0.97, y: this.reduceAnimation ? 1 : 0.97 });
  }
}
