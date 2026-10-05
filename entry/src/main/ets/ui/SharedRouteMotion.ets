import { UIContext } from '@kit.ArkUI';
import { ItemSummary } from '../model/Item';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { ItemRouteParams } from '../navigation/RouteContract';
import { RouteName } from '../navigation/RouteName';
import { uiSpring } from './VisualStyle';

/**
 * 导航协议保持两页同时显示，geometryTransition 负责共享元素的位置和尺寸。
 * 页面透明度与共享元素在同一个原生弹簧事务中改变，完成后才释放退出页。
 */
export class SharedRouteMotion {
  private static context?: UIContext;
  private static item?: ItemSummary;
  private static itemKey: string = '';
  private static search: boolean = false;
  private static opening: boolean = false;
  private static ready: boolean = false;
  private static running: boolean = false;
  private static proxy?: NavigationTransitionProxy;
  private static push: boolean = false;
  private static searchMotion: boolean = false;
  private static interactive: boolean = false;
  private static waitId: number = -1;

  static clear(): void {
    SharedRouteMotion.clearWait();
    SharedRouteMotion.context = undefined;
    SharedRouteMotion.item = undefined;
    SharedRouteMotion.itemKey = '';
    SharedRouteMotion.search = false;
    SharedRouteMotion.opening = false;
    SharedRouteMotion.ready = false;
    SharedRouteMotion.running = false;
    SharedRouteMotion.interactive = false;
    SharedRouteMotion.proxy = undefined;
    SharedRouteMotion.resetVisuals();
  }

  private static resetVisuals(): void {
    AppStorage.setOrCreate<string>('itemtrace.sharedItemSource', '');
    AppStorage.setOrCreate<boolean>('itemtrace.sharedItemExpanded', true);
    AppStorage.setOrCreate<boolean>('itemtrace.searchSourceHidden', false);
    AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', true);
    AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', 1);
    AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', '');
  }

  static preview(itemId: string): ItemSummary | undefined {
    return SharedRouteMotion.opening && SharedRouteMotion.item?.id === itemId ? SharedRouteMotion.item : undefined;
  }

  static itemTransitionId(itemId: string): string {
    return SharedRouteMotion.opening && SharedRouteMotion.item?.id === itemId ? SharedRouteMotion.itemKey : '';
  }

  /**
   * 编辑保存可能替换整个导航栈；目的页释放后恢复入口，避免隐藏状态留到下一次打开。
   */
  static release(route: RouteName, itemId?: string): void {
    if (SharedRouteMotion.proxy !== undefined) { return; }
    if (route === RouteName.ITEM_DETAIL && SharedRouteMotion.item?.id === itemId) {
      SharedRouteMotion.item = undefined;
      SharedRouteMotion.itemKey = '';
      AppStorage.setOrCreate<string>('itemtrace.sharedItemSource', '');
      AppStorage.setOrCreate<boolean>('itemtrace.sharedItemExpanded', true);
    }
    if (route === RouteName.SEARCH && SharedRouteMotion.search) {
      SharedRouteMotion.search = false;
      AppStorage.setOrCreate<boolean>('itemtrace.searchSourceHidden', false);
      AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', true);
    }
    if (AppStorage.get<string>('itemtrace.sharedPageRoute') === route) {
      AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', 1);
      AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', '');
    }
  }

  private static hasSource(context: UIContext, key: string): boolean {
    try {
      const frame = context.getComponentUtils().getRectangleById(`frame:${key}`);
      return frame.size.width > 0 && frame.size.height > 0;
    } catch (_) {
      return false;
    }
  }

  static openItem(context: UIContext, item: ItemSummary, key: string, reduceAnimation: boolean): void {
    if (SharedRouteMotion.opening || SharedRouteMotion.proxy !== undefined) { return; }
    SharedRouteMotion.context = context;
    SharedRouteMotion.item = item;
    const shared = !reduceAnimation && SharedRouteMotion.hasSource(context, key);
    SharedRouteMotion.itemKey = shared ? key : '';
    SharedRouteMotion.opening = shared;
    SharedRouteMotion.ready = false;
    AppStorage.setOrCreate<boolean>('itemtrace.sharedItemExpanded', !shared);
    AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', shared ? 0 : 1);
    AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', RouteName.ITEM_DETAIL);
    NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: item.id } }).then((opened: boolean) => {
      if (!opened) { SharedRouteMotion.clear(); }
    });
  }

  static openSearch(context: UIContext, reduceAnimation: boolean): void {
    if (SharedRouteMotion.opening || SharedRouteMotion.proxy !== undefined) { return; }
    SharedRouteMotion.context = context;
    SharedRouteMotion.search = !reduceAnimation;
    SharedRouteMotion.opening = !reduceAnimation;
    SharedRouteMotion.ready = false;
    AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', reduceAnimation);
    AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', reduceAnimation ? 1 : 0);
    AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', RouteName.SEARCH);
    NavigationHelper.pushUrl({ url: RouteName.SEARCH, params: { source: 'home-search' } }).then((opened: boolean) => {
      if (!opened) { SharedRouteMotion.clear(); }
    });
  }

  static targetReady(itemId?: string): void {
    if (itemId !== undefined && SharedRouteMotion.item?.id !== itemId) { return; }
    if (itemId === undefined && !SharedRouteMotion.search) { return; }
    const route = AppStorage.get<string>('itemtrace.sharedPageRoute');
    if (route !== (itemId === undefined ? RouteName.SEARCH : RouteName.ITEM_DETAIL)) { return; }
    SharedRouteMotion.ready = true;
    SharedRouteMotion.run();
  }

  static startReturn(itemId: string): void {
    const context = SharedRouteMotion.context;
    if (context === undefined || SharedRouteMotion.item?.id !== itemId ||
      SharedRouteMotion.itemKey.length === 0 || SharedRouteMotion.opening || SharedRouteMotion.proxy !== undefined ||
      !SharedRouteMotion.hasSource(context, SharedRouteMotion.itemKey)) { return; }
    SharedRouteMotion.interactive = true;
    NavigationHelper.back();
  }

  static updateReturn(progress: number): void {
    if (!SharedRouteMotion.interactive) { return; }
    SharedRouteMotion.proxy?.updateTransition?.(Math.max(0, Math.min(1, progress)));
  }

  static endReturn(commit: boolean): void {
    if (!SharedRouteMotion.interactive) { return; }
    if (commit) { SharedRouteMotion.proxy?.finishTransition(); }
    else { SharedRouteMotion.proxy?.cancelTransition?.(); }
  }

  static transition(from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    const itemId = SharedRouteMotion.item?.id;
    const itemPush = SharedRouteMotion.opening && SharedRouteMotion.itemKey.length > 0 &&
      to.name === RouteName.ITEM_DETAIL && (to.param as ItemRouteParams | undefined)?.itemId === itemId;
    const itemPop = SharedRouteMotion.itemKey.length > 0 && from.name === RouteName.ITEM_DETAIL &&
      (from.param as ItemRouteParams | undefined)?.itemId === itemId;
    const searchPush = SharedRouteMotion.opening && SharedRouteMotion.search && to.name === RouteName.SEARCH && !from.name;
    const searchPop = SharedRouteMotion.search && from.name === RouteName.SEARCH && !to.name;
    const push = operation === NavigationOperation.PUSH;
    if (!((push && (itemPush || searchPush)) || (operation === NavigationOperation.POP && (itemPop || searchPop)))) {
      return undefined;
    }
    SharedRouteMotion.opening = false;
    SharedRouteMotion.searchMotion = searchPush || searchPop;
    const interactive = SharedRouteMotion.interactive && itemPop;
    AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', SharedRouteMotion.searchMotion ? RouteName.SEARCH : RouteName.ITEM_DETAIL);
    return {
      timeout: interactive ? undefined : 1600,
      isInteractive: interactive,
      transition: (proxy: NavigationTransitionProxy) => {
        SharedRouteMotion.proxy = proxy;
        SharedRouteMotion.push = push;
        SharedRouteMotion.running = false;
        if (!push || SharedRouteMotion.ready) { SharedRouteMotion.run(); }
        else {
          SharedRouteMotion.waitId = setTimeout(() => {
            SharedRouteMotion.resetVisuals();
            proxy.finishTransition();
          }, 400);
        }
      },
      onTransitionEnd: (success: boolean) => {
        SharedRouteMotion.clearWait();
        SharedRouteMotion.proxy = undefined;
        SharedRouteMotion.running = false;
        SharedRouteMotion.interactive = false;
        if (!success && push) {
          SharedRouteMotion.clear();
          return;
        }
        if (!success && !push) {
          const context = SharedRouteMotion.context;
          context?.animateTo({ duration: 0 }, () => {
            AppStorage.setOrCreate<string>('itemtrace.sharedItemSource', SharedRouteMotion.itemKey);
            AppStorage.setOrCreate<boolean>('itemtrace.sharedItemExpanded', true);
            AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', 1);
          });
        }
        if (success && push && searchPush) {
          try {
            SharedRouteMotion.context?.getFocusController().requestFocus('itemtrace-search-input');
          } catch (_) {
          }
        }
        if (success && !push) {
          if (itemPop) {
            SharedRouteMotion.item = undefined;
            SharedRouteMotion.itemKey = '';
            AppStorage.setOrCreate<string>('itemtrace.sharedItemSource', '');
          }
          if (searchPop) { SharedRouteMotion.search = false; }
          AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', 1);
          AppStorage.setOrCreate<string>('itemtrace.sharedPageRoute', '');
        }
      }
    };
  }

  private static run(): void {
    const proxy = SharedRouteMotion.proxy;
    const context = SharedRouteMotion.context;
    if (proxy === undefined || context === undefined || SharedRouteMotion.running ||
      (SharedRouteMotion.push && !SharedRouteMotion.ready)) { return; }
    SharedRouteMotion.running = true;
    SharedRouteMotion.clearWait();
    const push = SharedRouteMotion.push;
    const options: AnimateParam = SharedRouteMotion.interactive ?
      { duration: 1000, curve: Curve.Linear } : uiSpring(false, 0.48, 0.86);
    if (!SharedRouteMotion.interactive) { options.onFinish = () => proxy.finishTransition(); }
    context.animateTo(options, () => {
      if (SharedRouteMotion.searchMotion) {
        AppStorage.setOrCreate<boolean>('itemtrace.searchSourceHidden', push);
        AppStorage.setOrCreate<boolean>('itemtrace.searchExpanded', push);
      } else {
        AppStorage.setOrCreate<string>('itemtrace.sharedItemSource', push ? SharedRouteMotion.itemKey : '');
        AppStorage.setOrCreate<boolean>('itemtrace.sharedItemExpanded', push);
      }
      AppStorage.setOrCreate<number>('itemtrace.sharedPageProgress', push ? 1 : 0);
    });
  }

  private static clearWait(): void {
    if (SharedRouteMotion.waitId >= 0) { clearTimeout(SharedRouteMotion.waitId); }
    SharedRouteMotion.waitId = -1;
  }
}
