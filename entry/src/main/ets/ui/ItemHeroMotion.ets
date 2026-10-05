import { UIContext } from '@kit.ArkUI';
import { ItemSummary } from '../model/Item';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { RouteName } from '../navigation/RouteName';
import { ItemRouteParams } from '../navigation/RouteContract';

export class HeroFrame {
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
}

export class ItemHeroSource {
  item: ItemSummary;
  key: string;
  frame: HeroFrame;
  target?: HeroFrame;
  photoPath?: string;

  constructor(item: ItemSummary, key: string, frame: HeroFrame) {
    this.item = item;
    this.key = key;
    this.frame = frame;
    this.photoPath = item.photoPath;
  }
}

type HeroAnimation = (source: ItemHeroSource, proxy: NavigationTransitionProxy,
  operation: NavigationOperation, interactive: boolean) => void;

/**
 * 只协调列表缩略图与详情缩略图的转场，不参与物品读取和库存操作。
 * 目标布局完成后再开始动画，手势取消由 Navigation 恢复导航栈。
 */
export class ItemHeroMotion {
  private static source?: ItemHeroSource;
  private static context?: UIContext;
  private static animate?: HeroAnimation;
  private static complete?: () => void;
  private static proxy?: NavigationTransitionProxy;
  private static operation: NavigationOperation = NavigationOperation.PUSH;
  private static interactive: boolean = false;
  private static waiting: boolean = false;
  private static opening: boolean = false;
  private static timeoutId: number = -1;

  static register(animate: HeroAnimation, complete: () => void): void {
    ItemHeroMotion.animate = animate;
    ItemHeroMotion.complete = complete;
    complete();
  }

  static unregister(): void {
    ItemHeroMotion.clearWait();
    ItemHeroMotion.complete?.();
    ItemHeroMotion.animate = undefined;
    ItemHeroMotion.complete = undefined;
    ItemHeroMotion.source = undefined;
    ItemHeroMotion.context = undefined;
    ItemHeroMotion.proxy = undefined;
    ItemHeroMotion.opening = false;
    ItemHeroMotion.interactive = false;
  }

  static frame(context: UIContext, key: string): HeroFrame | undefined {
    try {
      const rectangle = context.getComponentUtils().getRectangleById(key);
      if (rectangle.size.width <= 0 || rectangle.size.height <= 0) { return undefined; }
      const frame = new HeroFrame();
      frame.x = context.px2vp(rectangle.windowOffset.x);
      frame.y = context.px2vp(rectangle.windowOffset.y);
      frame.width = context.px2vp(rectangle.size.width);
      frame.height = context.px2vp(rectangle.size.height);
      return frame;
    } catch (_) {
      return undefined;
    }
  }

  static open(context: UIContext, item: ItemSummary, key: string, reduceAnimation: boolean): void {
    if (ItemHeroMotion.proxy !== undefined || ItemHeroMotion.opening) { return; }
    const frame = reduceAnimation ? undefined : ItemHeroMotion.frame(context, key);
    ItemHeroMotion.source = frame === undefined ? undefined : new ItemHeroSource(item, key, frame);
    ItemHeroMotion.context = context;
    ItemHeroMotion.opening = frame !== undefined;
    NavigationHelper.pushUrl({ url: RouteName.ITEM_DETAIL, params: { itemId: item.id } });
  }

  static preview(itemId: string): ItemSummary | undefined {
    return ItemHeroMotion.source?.item.id === itemId ? ItemHeroMotion.source.item : undefined;
  }

  static reportTarget(context: UIContext, itemId: string, key: string): void {
    const source = ItemHeroMotion.source;
    if (source?.item.id !== itemId) { return; }
    source.target = ItemHeroMotion.frame(context, key);
    if (ItemHeroMotion.waiting && source.target !== undefined) { ItemHeroMotion.run(); }
  }

  static updatePhoto(itemId: string, path: string): void {
    if (ItemHeroMotion.source?.item.id === itemId) {
      ItemHeroMotion.source.photoPath = path.length > 0 ? path : undefined;
    }
  }

  static transition(from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    const source = ItemHeroMotion.source;
    const fromItemId = (from.param as ItemRouteParams | undefined)?.itemId;
    const toItemId = (to.param as ItemRouteParams | undefined)?.itemId;
    if (source === undefined || ItemHeroMotion.animate === undefined ||
      !((operation === NavigationOperation.PUSH && ItemHeroMotion.opening &&
          to.name === RouteName.ITEM_DETAIL && toItemId === source.item.id) ||
        (operation === NavigationOperation.POP && from.name === RouteName.ITEM_DETAIL &&
          fromItemId === source.item.id &&
          (!to.name || to.name === RouteName.ITEM_LIST || to.name === RouteName.SEARCH)))) {
      return undefined;
    }
    ItemHeroMotion.opening = false;
    if (operation === NavigationOperation.POP && ItemHeroMotion.context !== undefined) {
      const frame = ItemHeroMotion.frame(ItemHeroMotion.context, source.key);
      if (frame === undefined) { return undefined; }
      source.frame = frame;
    }
    const interactive = ItemHeroMotion.interactive;
    return {
      timeout: interactive ? undefined : 1600, isInteractive: interactive,
      transition: (proxy: NavigationTransitionProxy) => {
        ItemHeroMotion.proxy = proxy;
        ItemHeroMotion.operation = operation;
        ItemHeroMotion.waiting = true;
        if (source.target !== undefined) {
          ItemHeroMotion.run();
        } else {
          ItemHeroMotion.timeoutId = setTimeout(() => {
            ItemHeroMotion.waiting = false;
            proxy.finishTransition();
          }, 500);
        }
      },
      onTransitionEnd: (success: boolean) => {
        ItemHeroMotion.clearWait();
        ItemHeroMotion.proxy = undefined;
        ItemHeroMotion.interactive = false;
        ItemHeroMotion.complete?.();
        if (success && operation === NavigationOperation.POP && ItemHeroMotion.source === source) {
          ItemHeroMotion.source = undefined;
          ItemHeroMotion.context = undefined;
        }
      }
    };
  }

  static startReturn(itemId: string): void {
    if (ItemHeroMotion.source?.target === undefined || ItemHeroMotion.proxy !== undefined) { return; }
    if (ItemHeroMotion.source.item.id !== itemId) { return; }
    if (ItemHeroMotion.context === undefined ||
      ItemHeroMotion.frame(ItemHeroMotion.context, ItemHeroMotion.source.key) === undefined) { return; }
    ItemHeroMotion.interactive = true;
    NavigationHelper.back();
  }

  static updateReturn(progress: number): void {
    ItemHeroMotion.proxy?.updateTransition?.(Math.max(0, Math.min(1, progress)));
  }

  static endReturn(commit: boolean): void {
    if (!ItemHeroMotion.interactive) { return; }
    if (commit) { ItemHeroMotion.proxy?.finishTransition(); }
    else { ItemHeroMotion.proxy?.cancelTransition?.(); }
  }

  private static run(): void {
    const source = ItemHeroMotion.source;
    const proxy = ItemHeroMotion.proxy;
    if (!ItemHeroMotion.waiting || source?.target === undefined || proxy === undefined) { return; }
    ItemHeroMotion.clearWait();
    ItemHeroMotion.animate?.(source, proxy, ItemHeroMotion.operation, ItemHeroMotion.interactive);
  }

  private static clearWait(): void {
    if (ItemHeroMotion.timeoutId >= 0) { clearTimeout(ItemHeroMotion.timeoutId); }
    ItemHeroMotion.timeoutId = -1;
    ItemHeroMotion.waiting = false;
  }
}
