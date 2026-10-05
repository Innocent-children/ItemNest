import { describe, it, expect } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { seedLegacyDatabase } from './InventoryUpgradeDevice.test';
import { DATABASE_VERSION } from '../../../main/ets/data/rdb/ItemSchema';
import { migrateToLatest } from '../../../main/ets/data/rdb/RdbDatabase';
import { ResultSetReader } from '../../../main/ets/data/rdb/ResultSetReader';

const TEST_DATABASE_NAME = 'itemtrace-barcode-migration-test.db';

export default function barcodeMigrationTest() {
  describe('Barcode migration', () => {
    it('v10 旧物品升级到当前版本保留记录并新增条码列', 0, async () => {
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      const context = ability.context;
      try {
        await relationalStore.deleteRdbStore(context, TEST_DATABASE_NAME);
      } catch (_) {
      }
      const store = await relationalStore.getRdbStore(context, {
        name: TEST_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S3
      });
      try {
        await seedLegacyDatabase(store, 10);
        await store.insert('item', { id: 'old-item', name: '旧物品', quantity: 1, unit: '个', photo_state: 'NONE', created_at: 1, updated_at: 1 });

        await migrateToLatest(store);
        expect(store.version).assertEqual(DATABASE_VERSION);
        const resultSet = await store.querySql("SELECT name, barcode FROM item WHERE id = 'old-item'");
        try {
          expect(ResultSetReader.goToNextRow(resultSet)).assertTrue();
          expect(ResultSetReader.readString(resultSet, 'name')).assertEqual('旧物品');
          expect(ResultSetReader.readString(resultSet, 'barcode')).assertEqual(undefined);
        } finally {
          ResultSetReader.close(resultSet);
        }
      } finally {
        store.close();
        await relationalStore.deleteRdbStore(context, TEST_DATABASE_NAME);
      }
    });
  });
}
