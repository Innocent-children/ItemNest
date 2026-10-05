import { FakeStockThresholdRepository } from './FakeStockThresholdRepository';
import { describe, it, expect } from '@ohos/hypium';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { LowStockService } from '../../../main/ets/service/LowStockService';
import { FakeItemRepository } from './FakeItemRepository';


function createService(thresholds: FakeStockThresholdRepository, withItem: boolean = true): LowStockService {
  const items = new FakeItemRepository();
  if (withItem) {
    items.items.push({
      id: 'item-1', name: '纸巾', quantity: 2, unit: ItemUnit.PACK,
      photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
    });
  }
  return new LowStockService(thresholds, items, () => 1234);
}

export default function lowStockServiceTest() {
  describe('LowStockService', () => {
    it('读取已保存阈值并允许未配置状态', 0, async () => {
      const thresholds = new FakeStockThresholdRepository();
      thresholds.thresholds.push({ itemId: 'item-1', threshold: 3, enabled: true, updatedAt: 1 });
      const service = createService(thresholds);

      const existing = await service.getThreshold('item-1');
      const missing = await service.getThreshold('item-2');

      expect(existing.ok).assertTrue();
      expect(missing.ok).assertTrue();
      if (existing.ok && missing.ok) {
        expect(existing.getData()?.threshold).assertEqual(3);
        expect(missing.getData() === undefined).assertTrue();
      }
    });

    it('保存最多两位小数的阈值和启用状态', 0, async () => {
      const thresholds = new FakeStockThresholdRepository();
      const result = await createService(thresholds).saveThreshold('item-1', 2.35, true);

      expect(result.ok).assertTrue();
      expect(thresholds.saveCallCount).assertEqual(1);
      if (result.ok) {
        expect(result.getData().threshold).assertEqual(2.35);
        expect(result.getData().enabled).assertTrue();
        expect(result.getData().updatedAt).assertEqual(1234);
      }
    });

    it('拒绝负数和超过两位小数的阈值', 0, async () => {
      const thresholds = new FakeStockThresholdRepository();
      const service = createService(thresholds);

      const negative = await service.saveThreshold('item-1', -1, true);
      const tooPrecise = await service.saveThreshold('item-1', 1.001, true);

      expect(negative.ok).assertFalse();
      expect(tooPrecise.ok).assertFalse();
      expect(thresholds.saveCallCount).assertEqual(0);
    });

    it('物品不存在时不写入阈值', 0, async () => {
      const thresholds = new FakeStockThresholdRepository();
      const result = await createService(thresholds, false).saveThreshold('item-1', 1, true);

      expect(result.ok).assertFalse();
      expect(thresholds.saveCallCount).assertEqual(0);
    });
  });
}
