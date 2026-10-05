import { curves } from '@kit.ArkUI';

// A zero-duration linear curve also disables spring physics for reduced motion.
export function uiSpring(reduceAnimation: boolean, response: number = 0.38,
  damping: number = 0.74): AnimateParam {
  return reduceAnimation ? { duration: 0, curve: Curve.Linear } :
    { curve: curves.springMotion(response, damping, 0.12) };
}

// Space lives inside scroll content, so the fixed glass Dock can blur rows below it.
export function dockContentInset(dockVisible: boolean, keyboardVisible: boolean): number {
  return dockVisible && !keyboardVisible ? 96 : 24;
}

// Styling only: action handlers and enabled states stay in the calling pages.
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
      .scale({ x: 1, y: 1 });
  }

  applyPressedAttribute(instance: ButtonAttribute): void {
    instance.scale({ x: this.reduceAnimation ? 1 : 0.98, y: this.reduceAnimation ? 1 : 0.98 });
  }
}
