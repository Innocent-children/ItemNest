import { describe, it, expect } from '@ohos/hypium';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { Item, ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ItemDeleteService } from '../../../main/ets/service/ItemDeleteService';
import { ItemDetailService } from '../../../main/ets/service/ItemDetailService';
import { ItemUpdateService } from '../../../main/ets/service/ItemUpdateService';
import { FakeItemRepository } from './FakeItemRepository';

function buildItem(): Item {
  return {
    id: 'item-1', name: '证件', quantity: 1, unit: ItemUnit.PIECE,
    locationPath: '书房 / 抽屉', photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
  };
}

export default function itemMaintenanceServiceTest() {
  describe('Item maintenance services', () => {
    it('读取、更新和确认删除物品', 0, async () => {
      const repository = new FakeItemRepository();
      repository.items.push(buildItem());
      const detailService = new ItemDetailService(repository);
      const updateService = new ItemUpdateService(repository, new ItemValidator(), () => 2);
      const deleteService = new ItemDeleteService(repository);
      expect((await detailService.getDetail('item-1')).ok).assertTrue();
      const updated = await updateService.update('item-1', {
        name: '证件', quantity: 2, unit: ItemUnit.PIECE, locationPath: '客厅 / 收纳箱'
      });
      expect(updated.ok).assertTrue();
      expect(repository.items[0].createdAt).assertEqual(1);
      expect(repository.items[0].updatedAt).assertEqual(2);
      expect((await deleteService.delete('item-1', false)).ok).assertFalse();
      expect(repository.items.length).assertEqual(1);
      expect((await deleteService.delete('item-1', true)).ok).assertTrue();
      expect(repository.items.length).assertEqual(0);
    });
  });
}
