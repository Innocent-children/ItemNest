import { describe, it, expect } from '@ohos/hypium';
import { DATABASE_NAME, DATABASE_VERSION, ITEM_TABLE } from '../../../main/ets/data/rdb/ItemSchema';

export default function itemSchemaTest() {
  describe('ItemSchema', () => {
    it('声明当前数据库标识和迁移版本', 0, () => {
      expect(DATABASE_VERSION).assertEqual(9);
      expect(DATABASE_NAME).assertEqual('itemtrace.db');
      expect(ITEM_TABLE).assertEqual('item');
    });
  });
}
