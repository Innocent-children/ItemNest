import { describe, it, expect } from '@ohos/hypium';
import { Result, success } from '../../../main/ets/common/Result';
import { TraceEventRepositoryPort } from '../../../main/ets/data/repository/TraceEventRepository';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { allocateLegacyReturns, OutstandingLoan, TraceEvent, TraceEventType } from '../../../main/ets/model/TraceEvent';
import { LendingService } from '../../../main/ets/service/LendingService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeTraceEventRepository implements TraceEventRepositoryPort {
  events: TraceEvent[] = [];

  async append(event: TraceEvent): Promise<Result<TraceEvent>> {
    this.events.push(event);
    return success(event);
  }

  async update(event: TraceEvent): Promise<Result<TraceEvent>> {
    const index = this.events.findIndex((existing: TraceEvent) => existing.id === event.id);
    this.events[index] = event;
    return success(event);
  }

  async listByItemId(itemId: string): Promise<Result<TraceEvent[]>> {
    return success(this.events.filter((event: TraceEvent) => event.itemId === itemId));
  }

  async listAll(): Promise<Result<TraceEvent[]>> {
    return success(this.events.slice());
  }
}

interface LendingHarness {
  events: FakeTraceEventRepository;
  items: FakeItemRepository;
  service: LendingService;
}

function createHarness(quantity: number = 5): LendingHarness {
  const events = new FakeTraceEventRepository();
  const items = new FakeItemRepository();
  items.items.push({
    id: 'item-1', name: '工具', quantity: quantity, unit: ItemUnit.PIECE,
    photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
  });
  return { events: events, items: items, service: new LendingService(events, items, () => 1000 + events.events.length) };
}

function historic(id: string, type: TraceEventType, quantity: number, createdAt: number): TraceEvent {
  return { id: id, itemId: 'item-1', type: type, quantity: quantity, createdAt: createdAt };
}

export default function lendingServiceTest() {
  describe('LendingService', () => {
    it('待还汇总合并不同物品，归还与撤销后立即减少', 0, async () => {
      const harness = createHarness(5);
      harness.items.items.push({ id: 'item-2', name: '书', quantity: 2, unit: ItemUnit.PIECE,
        photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1 });
      const first = (await harness.service.borrow('item-1', 3, '小张')).getData();
      const second = (await harness.service.borrow('item-2', 1, '小李')).getData();
      await harness.service.returnItem('item-1', 1, undefined, undefined, first.id);
      const loans = (await harness.service.getOutstandingLoans()).getData();
      expect(loans.length).assertEqual(2);
      expect(loans[0].loan.remainingQuantity).assertEqual(2);
      expect(loans[1].itemName).assertEqual('书');
      await harness.service.voidEvent('item-2', second.id);
      await harness.service.returnItem('item-1', 2, undefined, undefined, first.id);
      expect((await harness.service.getOutstandingLoans()).getData().length).assertEqual(0);
    });

    it('并发归还同一借出量时只记录一次', 0, async () => {
      const harness = createHarness(1);
      const borrow = await harness.service.borrow('item-1', 1, '小张');
      expect(borrow.ok).assertTrue();
      const results = await Promise.all([
        harness.service.returnItem('item-1', 1, undefined, undefined, borrow.getData().id),
        harness.service.returnItem('item-1', 1, undefined, undefined, borrow.getData().id)
      ]);
      expect(results.filter((result: Result<TraceEvent>) => result.ok).length).assertEqual(1);
      expect(harness.events.events.filter((event: TraceEvent) => event.type === TraceEventType.RETURN).length).assertEqual(1);
      const state = await harness.service.getState('item-1');
      expect(state.getData().borrowedQuantity).assertEqual(0);
      expect(state.getData().availableQuantity).assertEqual(1);
      expect(harness.items.items[0].quantity).assertEqual(1);
    });

    it('并发借出不能超过在手数量', 0, async () => {
      const harness = createHarness(3);
      const results = await Promise.all([
        harness.service.borrow('item-1', 2, '小张'), harness.service.borrow('item-1', 2, '小李')
      ]);
      expect(results.filter((result: Result<TraceEvent>) => result.ok).length).assertEqual(1);
      expect((await harness.service.getState('item-1')).getData().availableQuantity).assertEqual(1);
    });

    it('归还对应指定借出并保留借用人和备注', 0, async () => {
      const harness = createHarness(6);
      const first = await harness.service.borrow('item-1', 3, '小张', undefined, '周五前还');
      const second = await harness.service.borrow('item-1', 2, '小李', undefined, '借去维修');
      const returned = await harness.service.returnItem('item-1', 1, undefined, '已收到一个', second.getData().id);
      expect(returned.ok).assertTrue();
      expect(returned.getData().counterpart).assertEqual('小李');
      expect(returned.getData().note).assertEqual('已收到一个');
      expect(returned.getData().returnAllocations?.[0].borrowEventId).assertEqual(second.getData().id);
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.totalQuantity).assertEqual(6);
      expect(state.borrowedQuantity).assertEqual(4);
      expect(state.availableQuantity).assertEqual(2);
      expect(state.outstandingLoans.find((loan: OutstandingLoan) => loan.borrowEvent.id === first.getData().id)?.remainingQuantity).assertEqual(3);
      expect(state.outstandingLoans.find((loan: OutstandingLoan) => loan.borrowEvent.id === second.getData().id)?.remainingQuantity).assertEqual(1);
      expect((await harness.service.getEvents('item-1')).getData().find((event: TraceEvent) => event.id === first.getData().id)?.note).assertEqual('周五前还');
    });

    it('不能用别人的未归还数量补足所选借出的归还', 0, async () => {
      const harness = createHarness(4);
      const first = await harness.service.borrow('item-1', 1, '小张');
      await harness.service.borrow('item-1', 3, '小李');
      const returned = await harness.service.returnItem('item-1', 2, undefined, undefined, first.getData().id);
      expect(returned.ok).assertFalse();
      expect(harness.events.events.length).assertEqual(2);
    });

    it('拒绝非正数和超过两位小数的数量', 0, async () => {
      const harness = createHarness();
      expect((await harness.service.borrow('item-1', 1.001)).ok).assertFalse();
      expect((await harness.service.borrow('item-1', 0)).ok).assertFalse();
      expect((await harness.service.borrow('item-1', -1)).ok).assertFalse();
      expect(harness.events.events.length).assertEqual(0);
    });

    it('有归还的借出不能直接撤销或减少到已归还以下', 0, async () => {
      const harness = createHarness(5);
      const borrow = await harness.service.borrow('item-1', 3, '小张');
      await harness.service.returnItem('item-1', 2, undefined, undefined, borrow.getData().id);
      expect((await harness.service.voidEvent('item-1', borrow.getData().id)).ok).assertFalse();
      expect((await harness.service.correctEvent('item-1', borrow.getData().id, 1, '小张')).ok).assertFalse();
      expect((await harness.service.getState('item-1')).getData().borrowedQuantity).assertEqual(1);
    });

    it('纠正借用人和备注不改变库存或丢失归还关系', 0, async () => {
      const harness = createHarness(5);
      const borrow = await harness.service.borrow('item-1', 3, '错名字', undefined, '旧备注');
      await harness.service.returnItem('item-1', 1, undefined, '部分归还', borrow.getData().id);
      const corrected = await harness.service.correctEvent('item-1', borrow.getData().id, 3, '小张', '正确备注');
      expect(corrected.ok).assertTrue();
      expect(corrected.getData().counterpart).assertEqual('小张');
      expect(corrected.getData().note).assertEqual('正确备注');
      expect(corrected.getData().createdAt).assertEqual(borrow.getData().createdAt);
      expect((await harness.service.getState('item-1')).getData().borrowedQuantity).assertEqual(2);
      expect(harness.items.items[0].quantity).assertEqual(5);
    });

    it('撤销归还后可撤销借出并保留撤销记录', 0, async () => {
      const harness = createHarness(5);
      const borrow = await harness.service.borrow('item-1', 3, '小张');
      const returned = await harness.service.returnItem('item-1', 1, undefined, undefined, borrow.getData().id);
      expect((await harness.service.voidEvent('item-1', returned.getData().id)).ok).assertTrue();
      expect((await harness.service.voidEvent('item-1', borrow.getData().id)).ok).assertTrue();
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.borrowedQuantity).assertEqual(0);
      expect(state.availableQuantity).assertEqual(5);
      expect((await harness.service.getEvents('item-1')).getData().length).assertEqual(2);
      expect(harness.events.events.every((event: TraceEvent) => event.voidedAt !== undefined)).assertTrue();
    });

    it('用掉库存后不能撤销归还或降低归还量造成超借', 0, async () => {
      const harness = createHarness(5);
      const borrow = await harness.service.borrow('item-1', 4, '小张');
      const returned = await harness.service.returnItem('item-1', 3, undefined, undefined, borrow.getData().id);
      // Two in-hand items were consumed elsewhere; total is now three, one is still lent out.
      harness.items.items[0].quantity = 3;
      expect((await harness.service.voidEvent('item-1', returned.getData().id)).ok).assertFalse();
      expect((await harness.service.correctEvent('item-1', returned.getData().id, 0.5, undefined, undefined, borrow.getData().id)).ok).assertFalse();
      expect((await harness.service.getState('item-1')).getData().borrowedQuantity).assertEqual(1);
    });

    it('归还对象填错可纠正到另一笔借出', 0, async () => {
      const harness = createHarness(4);
      const first = await harness.service.borrow('item-1', 2, '小张');
      const second = await harness.service.borrow('item-1', 2, '小李');
      const returned = await harness.service.returnItem('item-1', 1, undefined, '还错对象', first.getData().id);
      const corrected = await harness.service.correctEvent('item-1', returned.getData().id, 1, undefined, '小李归还', second.getData().id);
      expect(corrected.ok).assertTrue();
      expect(corrected.getData().counterpart).assertEqual('小李');
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.outstandingLoans.find((loan: OutstandingLoan) => loan.borrowEvent.id === first.getData().id)?.remainingQuantity).assertEqual(2);
      expect(state.outstandingLoans.find((loan: OutstandingLoan) => loan.borrowEvent.id === second.getData().id)?.remainingQuantity).assertEqual(1);
    });

    it('历史超借保留并提示异常且禁止继续借出', 0, async () => {
      const harness = createHarness(3);
      harness.events.events.push(historic('old-borrow', TraceEventType.BORROW, 5, 1));
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.borrowedQuantity).assertEqual(5);
      expect(state.availableQuantity).assertEqual(0);
      expect((state.inventoryWarning ?? '').includes('超过总量')).assertTrue();
      expect((await harness.service.borrow('item-1', 1)).ok).assertFalse();
      expect((await harness.service.correctEvent('item-1', 'old-borrow', 5, '补写姓名', '仅补备注')).ok).assertTrue();
      expect((await harness.service.correctEvent('item-1', 'old-borrow', 6)).ok).assertFalse();
      expect((await harness.service.correctEvent('item-1', 'old-borrow', 3)).ok).assertTrue();
    });

    it('历史超额归还不会抵消之后的新借出且原证据保留', 0, async () => {
      const harness = createHarness(5);
      const extraReturn = historic('old-return', TraceEventType.RETURN, 2, 1);
      extraReturn.counterpart = '原姓名';
      extraReturn.note = '原备注';
      harness.events.events.push(extraReturn, historic('later-borrow', TraceEventType.BORROW, 2, 2));
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.borrowedQuantity).assertEqual(2);
      expect(state.unallocatedReturnQuantity).assertEqual(2);
      expect((state.inventoryWarning ?? '').includes('未对应借出')).assertTrue();
      expect(extraReturn.quantity).assertEqual(2);
      expect(extraReturn.counterpart).assertEqual('原姓名');
      expect(extraReturn.note).assertEqual('原备注');
      expect(extraReturn.returnAllocations?.length).assertEqual(0);
    });

    it('历史归还按先借先还分配且重复迁移保持已有关系', 0, () => {
      const first = historic('borrow-first', TraceEventType.BORROW, 2, 1);
      const second = historic('borrow-second', TraceEventType.BORROW, 3, 2);
      const returned = historic('return-old', TraceEventType.RETURN, 4, 3);
      const events = [returned, second, first];
      allocateLegacyReturns(events);
      expect(returned.returnAllocations?.[0].borrowEventId).assertEqual(first.id);
      expect(returned.returnAllocations?.[0].quantity).assertEqual(2);
      expect(returned.returnAllocations?.[1].borrowEventId).assertEqual(second.id);
      expect(returned.returnAllocations?.[1].quantity).assertEqual(2);
      expect(returned.legacyAllocated).assertTrue();
      const relations = JSON.stringify(returned.returnAllocations);
      allocateLegacyReturns(events);
      expect(JSON.stringify(returned.returnAllocations)).assertEqual(relations);
      expect(events.length).assertEqual(3);
    });

    it('历史超额归还只分配真实借出剩余并保留多余数量', 0, async () => {
      const harness = createHarness(3);
      harness.events.events.push(historic('borrow-old', TraceEventType.BORROW, 2, 1), historic('return-extra', TraceEventType.RETURN, 5, 2));
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.borrowedQuantity).assertEqual(0);
      expect(state.unallocatedReturnQuantity).assertEqual(3);
      expect(harness.events.events[1].quantity).assertEqual(5);
      expect(harness.events.events[1].returnAllocations?.[0].quantity).assertEqual(2);
    });

    it('已有归还关联在系统时间变化后仍正确并不被历史分配覆盖', 0, () => {
      const borrow = historic('borrow-new', TraceEventType.BORROW, 3, 3);
      const linked = historic('return-linked', TraceEventType.RETURN, 1, 1);
      linked.returnAllocations = [{ borrowEventId: borrow.id, quantity: 1 }];
      const legacy = historic('return-legacy', TraceEventType.RETURN, 3, 4);
      allocateLegacyReturns([linked, borrow, legacy]);
      expect(linked.returnAllocations[0].quantity).assertEqual(1);
      expect(legacy.returnAllocations?.[0].quantity).assertEqual(2);
    });

    it('两位小数的借还累计不会产生浮点尾差', 0, async () => {
      const harness = createHarness(0.3);
      const borrow = await harness.service.borrow('item-1', 0.3, '小张');
      expect((await harness.service.returnItem('item-1', 0.1, undefined, undefined, borrow.getData().id)).ok).assertTrue();
      expect((await harness.service.returnItem('item-1', 0.2, undefined, undefined, borrow.getData().id)).ok).assertTrue();
      const state = (await harness.service.getState('item-1')).getData();
      expect(state.borrowedQuantity).assertEqual(0);
      expect(state.availableQuantity).assertEqual(0.3);
    });
  });
}
