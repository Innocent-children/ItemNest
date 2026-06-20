import { describe, it, expect } from '@ohos/hypium';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { ItemUnit } from '../../../main/ets/model/Item';
import { ItemCreateService } from '../../../main/ets/service/ItemCreateService';
import { FakeItemRepository } from './FakeItemRepository';

export default function itemCreateServiceTest() {
  describe('ItemCreateService', () => {
    it('只填写名称时使用默认数量和单位', 0, async () => {
      const repository = new FakeItemRepository();
      const service = new ItemCreateService(repository, new ItemValidator(), () => 1000);
      const result = await service.create({ name: '感冒药' });
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().quantity).assertEqual(1);
        expect(result.getData().unit).assertEqual(ItemUnit.PIECE);
      }
      expect(repository.items.length).assertEqual(1);
    });

    it('校验失败或写入失败不生成半成品', 0, async () => {
      const repository = new FakeItemRepository();
      const service = new ItemCreateService(repository, new ItemValidator(), () => 1000);
      expect((await service.create({ name: ' ' })).ok).assertFalse();
      repository.failNextOperation = true;
      expect((await service.create({ name: '食品' })).ok).assertFalse();
      expect(repository.items.length).assertEqual(0);
    });
  });
}
