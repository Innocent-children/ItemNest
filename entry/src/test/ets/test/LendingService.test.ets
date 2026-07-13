import { describe, it, expect } from '@ohos/hypium';
import { Result, success } from '../../../main/ets/common/Result';
import { TraceEventRepositoryPort } from '../../../main/ets/data/repository/TraceEventRepository';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { TraceEvent, TraceEventType } from '../../../main/ets/model/TraceEvent';
import { LendingService } from '../../../main/ets/service/LendingService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeTraceEventRepository implements TraceEventRepositoryPort {
  events: TraceEvent[] = [];

  async append(event: TraceEvent): Promise<Result<TraceEvent>> {
    this.events.push(event);
    return success(event);
  }

  async listByItemId(itemId: string): Promise<Result<TraceEvent[]>> {
    return success(this.events.filter((event: TraceEvent) => event.itemId === itemId));
  }

  async listAll(): Promise<Result<TraceEvent[]>> {
    return success(this.events.slice());
  }
}

function createService(events: FakeTraceEventRepository): LendingService {
  const items = new FakeItemRepository();
  items.items.push({
    id: 'item-1', name: '工具', quantity: 1, unit: ItemUnit.PIECE,
    photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
  });
  return new LendingService(events, items, () => 1000 + events.events.length);
}

export default function lendingServiceTest() {
  describe('LendingService', () => {
    it('并发归还同一借出量时只记录一次', 0, async () => {
      const events = new FakeTraceEventRepository();
      events.events.push({
        id: 'borrow-1', itemId: 'item-1', type: TraceEventType.BORROW, quantity: 1, createdAt: 1
      });
      const service = createService(events);

      const results = await Promise.all([
        service.returnItem('item-1', 1),
        service.returnItem('item-1', 1)
      ]);

      expect(results.filter((result: Result<TraceEvent>) => result.ok).length).assertEqual(1);
      expect(events.events.filter((event: TraceEvent) => event.type === TraceEventType.RETURN).length).assertEqual(1);
      const state = await service.getState('item-1');
      expect(state.ok).assertTrue();
      if (state.ok) {
        expect(state.getData().borrowedQuantity).assertEqual(0);
      }
    });

    it('拒绝超过两位小数的借出数量', 0, async () => {
      const events = new FakeTraceEventRepository();
      const result = await createService(events).borrow('item-1', 1.001);
      expect(result.ok).assertFalse();
      expect(events.events.length).assertEqual(0);
    });
  });
}
