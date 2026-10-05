import { curves } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

/**
 * 系统减少动画开启时，同时关闭弹簧效果和过渡时间。
 */
export function uiSpring(reduceAnimation: boolean, response: number = 0.38,
  damping: number = 0.74): AnimateParam {
  return reduceAnimation ? { duration: 0, curve: Curve.Linear } :
    { curve: curves.springMotion(response, damping, 0.12) };
}

/**
 * 浮动页签覆盖滚动内容，末尾需要留下可完整查看最后一行的空间。
 */
export function dockContentInset(dockVisible: boolean, keyboardVisible: boolean): number {
  return dockVisible && !keyboardVisible ? 96 : 24;
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
    instance.scale({ x: this.reduceAnimation ? 1 : 0.98, y: this.reduceAnimation ? 1 : 0.98 });
  }
}
