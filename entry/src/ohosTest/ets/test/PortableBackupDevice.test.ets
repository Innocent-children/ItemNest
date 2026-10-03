import { describe, it, expect } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { BackupPhotoCodec } from '../../../main/ets/common/BackupPhotoCodec';
import { migrateToLatest } from '../../../main/ets/data/rdb/RdbDatabase';
import { ResultSetReader } from '../../../main/ets/data/rdb/ResultSetReader';

const TEST_DATABASE_NAME = 'itemtrace-restore-transaction-test.db';

export default function portableBackupDeviceTest() {
  describe('Portable backup device', () => {
    it('恢复写入中途失败会保留原物品和批次', 0, async () => {
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      const context = ability.context;
      try { await relationalStore.deleteRdbStore(context, TEST_DATABASE_NAME); } catch (_) {}
      const store = await relationalStore.getRdbStore(context, {
        name: TEST_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S3
      });
      try {
        await migrateToLatest(store);
        await store.insert('item', { id: 'original', name: '原物品', quantity: 2, unit: '个',
          photo_state: 'NONE', created_at: 1, updated_at: 1 });
        let failed = false;
        const transaction = await store.createTransaction();
        try {
          await transaction.execute('DELETE FROM item');
          await transaction.insert('item', { id: 'replacement', name: '新物品', quantity: 1, unit: '个',
            photo_state: 'NONE', created_at: 2, updated_at: 2 });
          await transaction.insert('item', { id: 'replacement', name: '重复主键', quantity: 1, unit: '个',
            photo_state: 'NONE', created_at: 2, updated_at: 2 });
          await transaction.commit();
        } catch (_) {
          failed = true;
          await transaction.rollback();
        }
        expect(failed).assertTrue();
        const items = await store.querySql('SELECT id FROM item ORDER BY id');
        try {
          expect(ResultSetReader.goToNextRow(items)).assertTrue();
          expect(ResultSetReader.readString(items, 'id')).assertEqual('original');
          expect(ResultSetReader.goToNextRow(items)).assertFalse();
        } finally {
          ResultSetReader.close(items);
        }
        const batches = await store.querySql("SELECT item_id FROM batch WHERE item_id = 'original'");
        try {
          expect(ResultSetReader.goToNextRow(batches)).assertTrue();
        } finally {
          ResultSetReader.close(batches);
        }
      } finally {
        store.close();
        await relationalStore.deleteRdbStore(context, TEST_DATABASE_NAME);
      }
    });

    it('备份照片在设备系统 Base64 实现中往返一致', 0, () => {
      const bytes = new Uint8Array([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52]);
      const codec = new BackupPhotoCodec();
      const restored = codec.decode(codec.encode(bytes));
      expect(restored.length).assertEqual(bytes.length);
      for (let index = 0; index < bytes.length; index++) {
        expect(restored[index]).assertEqual(bytes[index]);
      }
    });
  });
}
