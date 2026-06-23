import { describe, it, expect } from '@ohos/hypium';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { NavigationHelper } from '../../../main/ets/navigation/NavigationHelper';
import { BatchRouteParams, NavigationRouteParams, requireBatchId, requireItemId } from '../../../main/ets/navigation/RouteContract';
import { RouteName } from '../../../main/ets/navigation/RouteName';

export default function abilityTest() {
  describe('Navigation route contract flow', () => {
    it('主入口和业务目的页使用稳定的 Navigation 路由名', 0, () => {
      expect(RouteName.HOME).assertEqual('pages/Index');
      expect(RouteName.ITEM_FORM).assertEqual('pages/ItemFormPage');
      expect(RouteName.ITEM_DETAIL).assertEqual('pages/ItemDetailPage');
      expect(RouteName.BATCH_FORM).assertEqual('pages/BatchFormPage');
    });

    it('返回刷新参数保留 revision、来源和查询条件', 0, () => {
      const params: NavigationRouteParams = {
        itemId: 'item-1',
        batchId: 'batch-1',
        mode: 'edit',
        returnTo: RouteName.ITEM_DETAIL,
        refreshAt: 12,
        query: new ItemQuery('药', '卧室 / 药箱', '药品')
      };
      const batchParams: BatchRouteParams = {
        itemId: params.itemId,
        batchId: params.batchId,
        mode: 'edit'
      };

      expect(requireItemId({ itemId: params.itemId }).ok).assertTrue();
      expect(requireBatchId(batchParams).ok).assertTrue();
      expect(params.returnTo).assertEqual(RouteName.ITEM_DETAIL);
      expect(params.refreshAt).assertEqual(12);
      expect(params.query?.normalized().name).assertEqual('药');
    });

    it('缺少关键标识时拒绝打开依赖 itemId 或 batchId 的页面', 0, () => {
      expect(requireItemId(undefined).ok).assertFalse();
      expect(requireItemId({ itemId: ' ' }).ok).assertFalse();
      expect(requireBatchId({ itemId: 'item-1' }).ok).assertFalse();
      expect(requireBatchId({ itemId: 'item-1', batchId: ' ' }).ok).assertFalse();
    });

    it('NavDestination 返回处理器可拦截并释放', 0, () => {
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
