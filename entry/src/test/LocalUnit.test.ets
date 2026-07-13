import { describe, it, expect } from '@ohos/hypium';
import { NavigationHelper } from '../main/ets/navigation/NavigationHelper';
import { NavigationRouteParams } from '../main/ets/navigation/RouteContract';
import { RouteName } from '../main/ets/navigation/RouteName';

function routeNames(): string[] {
  return [
    RouteName.HOME,
    RouteName.ITEM_LIST,
    RouteName.ITEM_DETAIL,
    RouteName.ITEM_FORM,
    RouteName.SEARCH,
    RouteName.SETTINGS,
    RouteName.BATCH_LIST,
    RouteName.BATCH_FORM,
    RouteName.LENDING,
    RouteName.LOCATION_MANAGEMENT,
    RouteName.CATEGORY_MANAGEMENT
  ];
}

export default function localUnitTest() {
  describe('Local navigation contract', () => {
    it('首页保留唯一 main_pages 根入口', 0, () => {
      expect(RouteName.HOME).assertEqual('pages/Index');
    });

    it('业务路由名称保持唯一', 0, () => {
      const names = routeNames();
      const uniqueNames = new Set<string>(names);
      expect(uniqueNames.size).assertEqual(names.length);
    });

    it('NavDestination 返回处理器可注册和释放', 0, () => {
      let handledCount = 0;
      const handler = (): boolean => {
        handledCount += 1;
        return true;
      };

      NavigationHelper.registerBackHandler(handler);
      expect(NavigationHelper.handleBackPressed()).assertTrue();
      NavigationHelper.unregisterBackHandler(handler);
      expect(NavigationHelper.handleBackPressed()).assertFalse();
      expect(handledCount).assertEqual(1);
    });

    it('叠加表单释放顶层处理器后恢复下层返回拦截', 0, () => {
      let bottomCalls = 0;
      let topCalls = 0;
      const bottomHandler = (): boolean => {
        bottomCalls += 1;
        return true;
      };
      const topHandler = (): boolean => {
        topCalls += 1;
        return true;
      };
      NavigationHelper.registerBackHandler(bottomHandler);
      NavigationHelper.registerBackHandler(topHandler);

      expect(NavigationHelper.handleBackPressed()).assertTrue();
      expect(topCalls).assertEqual(1);
      expect(bottomCalls).assertEqual(0);
      NavigationHelper.unregisterBackHandler(topHandler);
      expect(NavigationHelper.handleBackPressed()).assertTrue();
      expect(bottomCalls).assertEqual(1);
      NavigationHelper.unregisterBackHandler(bottomHandler);
    });

    it('导航栈未注册时返回可处理的失败结果', 0, async () => {
      const pushed = await NavigationHelper.pushUrl({ url: RouteName.ITEM_LIST });
      const replaced = await NavigationHelper.replaceUrl({ url: RouteName.SEARCH });

      expect(pushed).assertFalse();
      expect(replaced).assertFalse();
    });

    it('NavPathStack 返回结果会通知来源页监听', 0, () => {
      let receivedCount = 0;
      let receivedRefreshAt = 0;
      const listenerId = NavigationHelper.subscribeRouteResult((result: Object | undefined) => {
        const params = result as NavigationRouteParams | undefined;
        receivedCount += 1;
        receivedRefreshAt = params?.refreshAt ?? 0;
      });
      const firstResult: NavigationRouteParams = { refreshAt: 18, itemId: 'item-1' };
      const ignoredResult: NavigationRouteParams = { refreshAt: 19, itemId: 'item-2' };

      NavigationHelper.recordPopResult(firstResult);
      NavigationHelper.unsubscribeRouteResult(listenerId);
      NavigationHelper.recordPopResult(ignoredResult);
      NavigationHelper.recordPopResult(undefined);

      expect(receivedCount).assertEqual(1);
      expect(receivedRefreshAt).assertEqual(18);
    });
  });
}
