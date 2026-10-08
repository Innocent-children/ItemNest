import { describe, it, expect } from '@ohos/hypium';
import { PortableBackupPayload, PortableBackupValidation, PORTABLE_BACKUP_VERSION } from '../../../main/ets/common/PortableBackupValidation';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { TraceEventType } from '../../../main/ets/model/TraceEvent';

function backup(): PortableBackupPayload {
  return {
    version: PORTABLE_BACKUP_VERSION,
    exportedAt: 100,
    items: [{ id: 'item-1', name: '药品', quantity: 2, unit: ItemUnit.BOX, barcode: '123',
      photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1 }],
    batches: [{ id: 'batch-1', itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX,
      createdAt: 1, updatedAt: 1 }],
    locations: [],
    categories: [],
    traceEvents: [],
    thresholds: [{ itemId: 'item-1', threshold: 3, enabled: true, updatedAt: 1 }],
    photos: []
  };
}

export default function portableBackupValidationTest() {
  describe('Portable backup validation', () => {
    it('历史位置的完整名称和最近使用时间随备份保留，拒绝无效时间', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      const path = '柜'.repeat(100);
      payload.locations.push({ id: 'history-location', name: path, path: path, active: true,
        createdAt: 1, updatedAt: 1, lastUsedAt: 20 });
      const valid = validator.validate(JSON.stringify(payload));
      expect(valid.ok).assertTrue();
      expect(valid.getData().locations[0].lastUsedAt).assertEqual(20);
      payload.locations[0].lastUsedAt = -1;
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
    });
    it('收纳标签随位置备份且拒绝悬空和重复标签', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.locations.push({ id: 'location-1', name: '书房', path: '书房', active: true, createdAt: 1, updatedAt: 1 });
      payload.locationLabels = [{ token: '12345678123412341234123456789012', locationId: 'location-1' }];
      const valid = validator.validate(JSON.stringify(payload));
      expect(valid.ok).assertTrue();
      expect(validator.preview(valid.getData()).locationLabelCount).assertEqual(1);
      payload.locationLabels.push({ token: payload.locationLabels[0].token, locationId: 'location-1' });
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
      payload.locationLabels = [{ token: '12345678123412341234123456789012', locationId: 'missing' }];
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
    });
    it('预览有效备份的数量', 0, () => {
      const validator = new PortableBackupValidation();
      const result = validator.validate(JSON.stringify(backup()));
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(validator.preview(result.getData()).itemCount).assertEqual(1);
      }
    });

    it('恢复前能识别备份来源时间、照片、阈值和物品样例', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.photos.push({ itemId: 'item-1', bytesBase64: 'iVBORw0KGgo=' });
      for (let index = 2; index <= 7; index++) {
        payload.items.push({ id: `item-${index}`, name: `物品${index}`, quantity: 1, unit: ItemUnit.BOX,
          photoState: PhotoState.NONE, createdAt: index, updatedAt: index });
        payload.batches.push({ id: `batch-${index}`, itemId: `item-${index}`, quantity: 1, unit: ItemUnit.BOX,
          createdAt: index, updatedAt: index });
      }
      const result = validator.validate(JSON.stringify(payload));
      expect(result.ok).assertTrue();
      if (result.ok) {
        const preview = validator.preview(result.getData());
        expect(preview.exportedAt).assertEqual(100);
        expect(preview.photoCount).assertEqual(1);
        expect(preview.thresholdCount).assertEqual(1);
        expect(preview.itemCount).assertEqual(7);
        expect(preview.sampleNames.length).assertEqual(5);
        expect(preview.sampleNames[0]).assertEqual('药品');
        expect(preview.sampleNames[4]).assertEqual('物品5');
      }
    });

    it('旧v2耗尽批次不阻止恢复且重新计算有效到期日', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.items[0].expirationDate = '2026-01-01';
      payload.batches[0].quantity = 0;
      payload.batches[0].expirationDate = '2026-01-01';
      payload.batches.push({ id: 'fresh', itemId: 'item-1', quantity: 2, unit: ItemUnit.BOX,
        expirationDate: '2026-11-01', notes: '新补货', createdAt: 2, updatedAt: 2 });
      const result = validator.validate(JSON.stringify(payload));
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().items[0].expirationDate).assertEqual('2026-11-01');
        expect(result.getData().batches.length).assertEqual(2);
        expect(result.getData().batches[0].expirationDate).assertEqual('2026-01-01');
        expect(result.getData().batches[1].notes).assertEqual('新补货');
      }
      payload.batches[1].expirationDate = undefined;
      const withoutActiveDate = validator.validate(JSON.stringify(payload));
      expect(withoutActiveDate.ok).assertTrue();
      if (withoutActiveDate.ok) {
        expect(withoutActiveDate.getData().items[0].expirationDate === undefined).assertTrue();
      }
      payload.items[0].expirationDate = '2027-01-01';
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
    });

    it('旧超借和无法完整匹配的归还记录保留原数量及备注', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.traceEvents.push({ id: 'loan', itemId: 'item-1', type: TraceEventType.BORROW,
        quantity: 5, counterpart: '小王', note: '历史借出', createdAt: 1 });
      payload.traceEvents.push({ id: 'return', itemId: 'item-1', type: TraceEventType.RETURN,
        quantity: 8, note: '历史归还', createdAt: 2 });
      const result = validator.validate(JSON.stringify(payload));
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().items[0].quantity).assertEqual(2);
        expect(result.getData().traceEvents.length).assertEqual(2);
        expect(result.getData().traceEvents[0].quantity).assertEqual(5);
        const returned = result.getData().traceEvents[1];
        expect(returned.quantity).assertEqual(8);
        expect(returned.note).assertEqual('历史归还');
        expect(returned.legacyAllocated).assertTrue();
        expect(returned.returnAllocations?.length).assertEqual(1);
        expect(returned.returnAllocations?.[0].borrowEventId).assertEqual('loan');
        expect(returned.returnAllocations?.[0].quantity).assertEqual(5);
      }
    });

    it('新版关联、撤销标记和消耗记录在备份往返后完整保留', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.traceEvents.push({ id: 'loan', itemId: 'item-1', type: TraceEventType.BORROW,
        quantity: 2, counterpart: '小王', note: '借用理由', createdAt: 1, voidedAt: 4 });
      payload.traceEvents.push({ id: 'return', itemId: 'item-1', type: TraceEventType.RETURN,
        quantity: 1, counterpart: '小王', note: '归还说明', createdAt: 2, voidedAt: 3,
        returnAllocations: [{ borrowEventId: 'loan', quantity: 1 }], legacyAllocated: false });
      payload.traceEvents.push({ id: 'consume', itemId: 'item-1', batchId: 'batch-1', type: TraceEventType.CONSUME,
        quantity: 0.5, note: '用掉半盒', createdAt: 5 });
      const result = validator.validate(JSON.stringify(payload));
      expect(result.ok).assertTrue();
      if (result.ok) {
        const roundTrip = validator.validate(JSON.stringify(result.getData()));
        expect(roundTrip.ok).assertTrue();
        if (roundTrip.ok) {
          const events = roundTrip.getData().traceEvents;
          expect(events.length).assertEqual(3);
          expect(events[0].voidedAt).assertEqual(4);
          expect(events[1].voidedAt).assertEqual(3);
          expect(events[1].note).assertEqual('归还说明');
          expect(events[1].returnAllocations?.[0].borrowEventId).assertEqual('loan');
          expect(events[1].legacyAllocated).assertFalse();
          expect(events[2].type).assertEqual(TraceEventType.CONSUME);
          expect(events[2].batchId).assertEqual('batch-1');
        }
      }
    });

    it('拒绝归还关联丢失或累计超过所选借出记录', 0, () => {
      const validator = new PortableBackupValidation();
      const payload = backup();
      payload.traceEvents.push({ id: 'loan', itemId: 'item-1', type: TraceEventType.BORROW,
        quantity: 2, createdAt: 1 });
      payload.traceEvents.push({ id: 'return', itemId: 'item-1', type: TraceEventType.RETURN,
        quantity: 1, createdAt: 2, returnAllocations: [{ borrowEventId: 'missing', quantity: 1 }] });
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
      payload.traceEvents[1].returnAllocations = [{ borrowEventId: 'loan', quantity: 0.5 }];
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
      payload.traceEvents[1].returnAllocations = [{ borrowEventId: 'loan', quantity: 1 }];
      payload.traceEvents.push({ id: 'return-again', itemId: 'item-1', type: TraceEventType.RETURN,
        quantity: 2, createdAt: 3, returnAllocations: [{ borrowEventId: 'loan', quantity: 2 }] });
      expect(validator.validate(JSON.stringify(payload)).ok).assertFalse();
    });

    it('拒绝悬空批次、图片引用和重复库存阈值', 0, () => {
      const validator = new PortableBackupValidation();
      const missingItem = backup();
      missingItem.batches[0].itemId = 'missing';
      expect(validator.validate(JSON.stringify(missingItem)).ok).assertFalse();

      const leakedPath = backup();
      leakedPath.items[0].photoLocalId = '/private/photo';
      expect(validator.validate(JSON.stringify(leakedPath)).ok).assertFalse();

      const duplicate = backup();
      duplicate.thresholds.push(duplicate.thresholds[0]);
      expect(validator.validate(JSON.stringify(duplicate)).ok).assertFalse();
    });

    it('拒绝批次汇总不一致与循环位置', 0, () => {
      const validator = new PortableBackupValidation();
      const mismatch = backup();
      mismatch.batches[0].quantity = 1;
      expect(validator.validate(JSON.stringify(mismatch)).ok).assertFalse();

      const cycle = backup();
      cycle.locations.push({ id: 'a', name: '抽屉', parentId: 'b', path: '抽屉', active: true, createdAt: 1, updatedAt: 1 });
      cycle.locations.push({ id: 'b', name: '柜子', parentId: 'a', path: '柜子', active: true, createdAt: 1, updatedAt: 1 });
      expect(validator.validate(JSON.stringify(cycle)).ok).assertFalse();
    });

    it('拒绝悬空照片和同一物品的重复照片', 0, () => {
      const validator = new PortableBackupValidation();
      const orphan = backup();
      orphan.photos.push({ itemId: 'missing', bytesBase64: 'iVBORw0KGgo=' });
      expect(validator.validate(JSON.stringify(orphan)).ok).assertFalse();

      const duplicate = backup();
      duplicate.photos.push({ itemId: 'item-1', bytesBase64: 'iVBORw0KGgo=' });
      duplicate.photos.push({ itemId: 'item-1', bytesBase64: 'iVBORw0KGgo=' });
      expect(validator.validate(JSON.stringify(duplicate)).ok).assertFalse();
    });
  });
}
