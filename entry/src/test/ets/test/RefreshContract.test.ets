import { describe, it, expect } from '@ohos/hypium';
import { buildBatchRefreshParams, buildItemRefreshParams, getUnhandledRouteRefreshAt } from '../../../main/ets/navigation/RefreshContract';

export default function refreshContractTest() {
  describe('RefreshContract', () => {
    it('物品新增、编辑和删除返回 item 刷新参数', 0, () => {
      const params = buildItemRefreshParams(7, 'item-1');

      expect(params.refreshAt).assertEqual(7);
      expect(params.itemId).assertEqual('item-1');
      expect(params.batchId === undefined).assertTrue();
    });

    it('批次新增和编辑返回 item 与 batch 刷新参数', 0, () => {
      const params = buildBatchRefreshParams(8, 'item-1', 'batch-1');

      expect(params.refreshAt).assertEqual(8);
      expect(params.itemId).assertEqual('item-1');
      expect(params.batchId).assertEqual('batch-1');
    });

    it('来源页只处理未消费过的 refreshAt', 0, () => {
      expect(getUnhandledRouteRefreshAt({ refreshAt: 9, itemId: 'item-1' }, 0)).assertEqual(9);
      expect(getUnhandledRouteRefreshAt({ refreshAt: 9, itemId: 'item-1' }, 9)).assertEqual(0);
      expect(getUnhandledRouteRefreshAt({ refreshAt: 10, itemId: 'item-1' }, 9)).assertEqual(10);
    });

    it('缺少 refreshAt 或 refreshAt 非正数时不触发来源页刷新', 0, () => {
      expect(getUnhandledRouteRefreshAt(undefined, 0)).assertEqual(0);
      expect(getUnhandledRouteRefreshAt({}, 0)).assertEqual(0);
      expect(getUnhandledRouteRefreshAt({ refreshAt: 0, itemId: 'item-1' }, 0)).assertEqual(0);
      expect(getUnhandledRouteRefreshAt({ refreshAt: -1, itemId: 'item-1' }, 0)).assertEqual(0);
    });
  });
}
