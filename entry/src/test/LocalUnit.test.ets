import { describe, it, expect } from '@ohos/hypium';
import { NavigationHelper } from '../main/ets/navigation/NavigationHelper';
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
  });
}
