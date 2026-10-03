import { describe, it, expect } from '@ohos/hypium';
import { PortableBackupPayload, PortableBackupValidation, PORTABLE_BACKUP_VERSION } from '../../../main/ets/common/PortableBackupValidation';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';

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
    it('预览有效备份的数量', 0, () => {
      const validator = new PortableBackupValidation();
      const result = validator.validate(JSON.stringify(backup()));
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(validator.preview(result.getData()).itemCount).assertEqual(1);
      }
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
