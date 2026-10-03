import { describe, it, expect } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { migrateToLatest } from '../../../main/ets/data/rdb/RdbDatabase';
import { ResultSetReader } from '../../../main/ets/data/rdb/ResultSetReader';

const TEST_DATABASE_NAME = 'itemtrace-barcode-migration-test.db';

export default function barcodeMigrationTest() {
  describe('Barcode migration', () => {
    it('v10 旧物品升级到 v11 时保留记录并新增条码列', 0, async () => {
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
        const transaction = await store.createTransaction();
        await transaction.execute('CREATE TABLE item (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL)');
        await transaction.execute("INSERT INTO item (id, name) VALUES ('old-item', '旧物品')");
        await transaction.execute('PRAGMA user_version = 10');
        await transaction.commit();

        await migrateToLatest(store);
        expect(store.version).assertEqual(11);
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
