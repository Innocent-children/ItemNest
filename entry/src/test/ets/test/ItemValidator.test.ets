import { describe, it, expect } from '@ohos/hypium';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { ItemUnit } from '../../../main/ets/model/Item';

export default function itemValidatorTest() {
  describe('ItemValidator', () => {
    it('拒绝空白或超长名称', 0, () => {
      const validator = new ItemValidator();
      expect(validator.validate({ name: '   ' }).ok).assertFalse();
      expect(validator.validate({ name: 'a'.repeat(81) }).ok).assertFalse();
    });

    it('拒绝非法数量和提醒天数', 0, () => {
      const validator = new ItemValidator();
      expect(validator.validate({ name: '药品', quantity: -1 }).ok).assertFalse();
      expect(validator.validate({ name: '药品', quantity: 1.234 }).ok).assertFalse();
      expect(validator.validate({ name: '药品', reminderDays: 366 }).ok).assertFalse();
    });

    it('规范化合法草稿并保留可选字段', 0, () => {
      const validator = new ItemValidator();
      const result = validator.validate({
        name: '  感冒药  ',
        quantity: 2.5,
        unit: ItemUnit.BOX,
        locationPath: '  卧室 / 药箱  ',
        reminderDays: 7,
        notes: '饭后服用'
      });
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().name).assertEqual('感冒药');
        expect(result.getData().locationPath).assertEqual('卧室 / 药箱');
        expect(result.getData().quantity).assertEqual(2.5);
      }
    });
  });
}
