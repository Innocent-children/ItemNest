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

    it('接受容易产生浮点误差的一位和两位小数', 0, () => {
      const validator = new ItemValidator();
      for (const quantity of [1.1, 0.29, 2.35, 4.01]) {
        expect(validator.validateQuantity(quantity).ok).assertTrue();
      }
      expect(validator.validateQuantity(1.101).ok).assertFalse();
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

    it('接受自定义分类并拒绝超长分类', 0, () => {
      const validator = new ItemValidator();
      const custom = validator.validate({ name: '备用电池', category: '  应急用品  ' });
      expect(custom.ok).assertTrue();
      if (custom.ok) {
        expect(custom.getData().category).assertEqual('应急用品');
      }
      expect(validator.validate({ name: '备用电池', category: 'a'.repeat(41) }).ok).assertFalse();
    });

    it('将条码独立于备注保存并限制长度', 0, () => {
      const validator = new ItemValidator();
      const result = validator.validate({ name: '备用电池', notes: '放在抽屉', barcode: '  6901234567890  ' });
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData().barcode).assertEqual('6901234567890');
        expect(result.getData().notes).assertEqual('放在抽屉');
      }
      expect(validator.validate({ name: '备用电池', barcode: 'a'.repeat(257) }).ok).assertFalse();
    });
  });
}
