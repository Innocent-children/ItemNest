import { describe, it, expect } from '@ohos/hypium';
import { ItemQuery } from '../../../main/ets/model/ItemQuery';
import { requireBatchId, requireItemId } from '../../../main/ets/navigation/RouteContract';

export default function routeContractTest() {
  describe('RouteContract', () => {
    it('缺少 itemId 或 batchId 时返回路由错误', 0, () => {
      expect(requireItemId(undefined).ok).assertFalse();
      expect(requireItemId({}).ok).assertFalse();
      expect(requireBatchId(undefined).ok).assertFalse();
      expect(requireBatchId({ itemId: 'item-1' }).ok).assertFalse();
    });

    it('读取有效 itemId 和 batchId 时去除空白', 0, () => {
      const item = requireItemId({ itemId: ' item-1 ' });
      const batch = requireBatchId({ itemId: 'item-1', batchId: ' batch-1 ' });
      expect(item.ok).assertTrue();
      expect(batch.ok).assertTrue();
      if (item.ok && batch.ok) {
        expect(item.getData()).assertEqual('item-1');
        expect(batch.getData()).assertEqual('batch-1');
      }
    });

    it('查询条件规范化名称、位置和自定义分类', 0, () => {
      const query = new ItemQuery('  药  ', '  卧室 / 药箱  ', '  应急用品  ').normalized();
      expect(query.name).assertEqual('药');
      expect(query.locationPath).assertEqual('卧室 / 药箱');
      expect(query.category).assertEqual('应急用品');
    });
  });
}
