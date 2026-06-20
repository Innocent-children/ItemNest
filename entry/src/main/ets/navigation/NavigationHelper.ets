
import { router } from '@kit.ArkUI';

export class NavigationHelper {
  static push(url: string, params?: object): Promise<void> {
    return router.pushUrl({ url, params: params ?? {} });
  }

  static goBack(): void {
    router.back({ url: '', params: {} as Record<string, Object> });
  }

  static goBackTo(url: string, params?: object): void {
    router.back({ url, params: params ?? {} as Record<string, Object> });
  }
}

