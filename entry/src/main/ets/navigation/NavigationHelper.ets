import { NavigationRouteParams } from './RouteContract';

class EmptyRouteParams {
}

export interface NavigationOptions {
  url: string;
  params?: NavigationRouteParams;
}

type NavigationBackHandler = () => boolean;

/**
 * 统一封装应用内导航。当前实现基于官方推荐的 Navigation/NavPathStack。
 */
export class NavigationHelper {
  private static pathStack: NavPathStack | undefined = undefined;
  private static backHandler: NavigationBackHandler | undefined = undefined;
  private static lastPopResult: Object | undefined = undefined;

  static registerPathStack(pathStack: NavPathStack): void {
    NavigationHelper.pathStack = pathStack;
  }

  static unregisterPathStack(pathStack: NavPathStack): void {
    if (NavigationHelper.pathStack === pathStack) {
      NavigationHelper.pathStack = undefined;
    }
  }

  static pushUrl(options: NavigationOptions): Promise<void> {
    if (NavigationHelper.pushWithPathStack(options)) {
      return Promise.resolve();
    }
    return Promise.reject(new Error('Navigation stack is not ready'));
  }

  static replaceUrl(options: NavigationOptions): Promise<void> {
    if (NavigationHelper.replaceWithPathStack(options)) {
      return Promise.resolve();
    }
    return Promise.reject(new Error('Navigation stack is not ready'));
  }

  static getParams(): Object | undefined {
    return NavigationHelper.lastPopResult ?? NavigationHelper.getPathStackParams();
  }

  static back(options?: NavigationOptions): void {
    NavigationHelper.popPathStack(options);
  }

  static registerBackHandler(handler: NavigationBackHandler): void {
    NavigationHelper.backHandler = handler;
  }

  static unregisterBackHandler(handler: NavigationBackHandler): void {
    if (NavigationHelper.backHandler === handler) {
      NavigationHelper.backHandler = undefined;
    }
  }

  static handleBackPressed(): boolean {
    const handler = NavigationHelper.backHandler;
    if (handler === undefined) {
      return false;
    }
    try {
      return handler();
    } catch (_) {
      return false;
    }
  }

  private static pushWithPathStack(options: NavigationOptions): boolean {
    const pathStack = NavigationHelper.pathStack;
    if (pathStack === undefined) {
      return false;
    }
    try {
      NavigationHelper.lastPopResult = undefined;
      pathStack.pushPathByName(options.url, NavigationHelper.toObjectParams(options.params), (popInfo: PopInfo) => {
        NavigationHelper.lastPopResult = popInfo.result;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  private static replaceWithPathStack(options: NavigationOptions): boolean {
    const pathStack = NavigationHelper.pathStack;
    if (pathStack === undefined) {
      return false;
    }
    try {
      NavigationHelper.lastPopResult = undefined;
      pathStack.clear(false);
      if (options.url.length > 0 && options.url !== 'pages/Index') {
        pathStack.pushPathByName(options.url, NavigationHelper.toObjectParams(options.params), (popInfo: PopInfo) => {
          NavigationHelper.lastPopResult = popInfo.result;
        }, false);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  private static popPathStack(options?: NavigationOptions): boolean {
    const pathStack = NavigationHelper.pathStack;
    if (pathStack === undefined) {
      return false;
    }
    try {
      if (pathStack.size() <= 0) {
        return false;
      }
      if (options?.params !== undefined) {
        pathStack.pop(NavigationHelper.toObjectParams(options.params));
      } else {
        pathStack.pop();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  private static getPathStackParams(): Object | undefined {
    const pathStack = NavigationHelper.pathStack;
    if (pathStack === undefined) {
      return undefined;
    }
    try {
      const size = pathStack.size();
      if (size <= 0) {
        return undefined;
      }
      return pathStack.getParamByIndex(size - 1) as Object | undefined;
    } catch (_) {
      return undefined;
    }
  }

  private static toObjectParams(params?: NavigationRouteParams): Object {
    return params === undefined ? new EmptyRouteParams() : params as Object;
  }
}
