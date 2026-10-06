import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppIcon } from '../../model/AppIcon';

export interface AppIconAdapter {
  isSupported(): boolean;
  getCurrent(): Promise<AppIcon>;
  setCurrent(icon: AppIcon): Promise<void>;
}

export class SystemAppIconAdapter implements AppIconAdapter {
  isSupported(): boolean {
    return deviceInfo.sdkApiVersion >= 26 && deviceInfo.apiAvailable('26.0.0');
  }

  async getCurrent(): Promise<AppIcon> {
    if (deviceInfo.sdkApiVersion >= 26) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        const icons = await bundleManager.getAlternateIcons();
        for (const icon of icons) {
          if (icon.enabled && icon.iconName === AppIcon.BUDDY) {
            return AppIcon.BUDDY;
          }
        }
      }
    }
    return AppIcon.GIRL;
  }

  async setCurrent(icon: AppIcon): Promise<void> {
    if (deviceInfo.sdkApiVersion >= 26) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        await bundleManager.setAlternateIcon(icon);
        return;
      }
    }
    throw new Error('当前系统不支持切换应用图标');
  }
}
