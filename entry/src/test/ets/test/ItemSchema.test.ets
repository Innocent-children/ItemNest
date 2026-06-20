import { describe, it, expect } from '@ohos/hypium';
import { DATABASE_NAME, DATABASE_VERSION, ITEM_TABLE } from '../../../main/ets/data/rdb/ItemSchema';

export default function itemSchemaTest() {
  describe('ItemSchema', () => {
    it('声明稳定的 v1 数据库标识', 0, () => {
      expect(DATABASE_VERSION).assertEqual(1);
      expect(DATABASE_NAME).assertEqual('itemtrace.db');
      expect(ITEM_TABLE).assertEqual('item');
    });
  });
}
