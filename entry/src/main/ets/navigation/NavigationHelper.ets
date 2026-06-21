import { router } from '@kit.ArkUI';

/**
 * 统一封装页面路由调用，集中处理已弃用的 @ohos.router API（pushUrl/getParams/back）。
 * 当前仍基于 router 实现，行为与之前一致；后续若整体迁移到 Navigation/NavPathStack，只需修改本文件。
 */
export class NavigationHelper {
  static pushUrl(options: router.RouterOptions): Promise<void> {
    return router.pushUrl(options);
  }

  static replaceUrl(options: router.RouterOptions): Promise<void> {
    return router.replaceUrl(options);
  }

  static getParams(): Object {
    return router.getParams();
  }

  static back(options?: router.RouterOptions): void {
    if (options === undefined) {
      router.back();
    } else {
      router.back(options);
    }
  }
}
