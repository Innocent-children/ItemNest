import { bundleManager } from '@kit.AbilityKit';

export async function readApplicationIcon(): Promise<string> {
  const icons = await bundleManager.getAlternateIcons();
  return icons.find((icon: bundleManager.AlternateIconInfo) => icon.enabled)?.iconName ?? 'moving_girl';
}
