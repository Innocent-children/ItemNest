import { describe, it, expect } from '@ohos/hypium';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ExpiryStatus } from '../../../main/ets/model/ExpiryStatus';
import { StockStatus } from '../../../main/ets/model/StockStatus';
import { ExpiryService } from '../../../main/ets/service/ExpiryService';

function itemWithDate(expirationDate?: string, reminderDays?: number, quantity: number = 1): Item {
  return {
    id: 'item', name: '测试物品', quantity: quantity, unit: ItemUnit.PIECE,
    expirationDate: expirationDate, reminderDays: reminderDays, photoState: PhotoState.NONE,
    createdAt: 1, updatedAt: 1
  };
}

export default function expiryServiceTest() {
  describe('ExpiryService', () => {
    it('按本地日期返回四种到期状态和待补货状态', 0, () => {
      const service = new ExpiryService();
      const today = new Date(2026, 5, 20);
      expect(service.getExpiryStatus(itemWithDate(), today)).assertEqual(ExpiryStatus.NO_EXPIRY_DATE);
      expect(service.getExpiryStatus(itemWithDate('2026-06-19'), today)).assertEqual(ExpiryStatus.EXPIRED);
      expect(service.getExpiryStatus(itemWithDate('2026-06-20'), today)).assertEqual(ExpiryStatus.DUE_SOON);
      expect(service.getExpiryStatus(itemWithDate('2026-06-27'), today)).assertEqual(ExpiryStatus.DUE_SOON);
      expect(service.getExpiryStatus(itemWithDate('2026-06-28'), today)).assertEqual(ExpiryStatus.NORMAL);
      expect(service.getStockStatus(itemWithDate(undefined, undefined, 0))).assertEqual(StockStatus.OUT_OF_STOCK);
      expect(service.getExpiryStatus(itemWithDate('2026-06-01', 7, 0), today)).assertEqual(ExpiryStatus.NO_EXPIRY_DATE);
    });
  });
}
