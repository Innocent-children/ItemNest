import { describe, it, expect } from '@ohos/hypium';
import { CategoryRecord } from '../../../main/ets/model/Category';
import { ItemUnit } from '../../../main/ets/model/Item';
import { activeCategoryNames, activeLocationText, refreshedUnit } from '../../../main/ets/service/ItemFlowPresentation';

function category(name: string, active: boolean, systemPreset: boolean): CategoryRecord {
  return { id: name, name: name, active: active, systemPreset: systemPreset, createdAt: 1, updatedAt: 1 };
}

export default function pageFlowPolicyTest() {
  describe('Item flow presentation', () => {
    it('停用预设分类和自建分类均不再出现在录入选项', 0, () => {
      const options = activeCategoryNames([
        category('药品', false, true), category('生活用品', true, true),
        category('旧分类', false, false), category('常用', true, false)
      ]);
      expect(options.length).assertEqual(2);
      expect(options.indexOf('药品')).assertEqual(-1);
      expect(options.indexOf('旧分类')).assertEqual(-1);
      expect(options[0]).assertEqual('生活用品');
      expect(activeCategoryNames([]).length).assertEqual(0);
    });

    it('批次刷新与保存前重读不会覆盖用户纠正的单位', 0, () => {
      expect(refreshedUnit(ItemUnit.BOX, ItemUnit.PIECE, ItemUnit.PIECE)).assertEqual(ItemUnit.BOX);
      expect(refreshedUnit(ItemUnit.PIECE, ItemUnit.PIECE, ItemUnit.BOTTLE)).assertEqual(ItemUnit.BOTTLE);
    });

    it('列表与详情以有效批次位置显示且清空库存不回显旧位置', 0, () => {
      expect(activeLocationText(['新位置'], '旧位置', 1)).assertEqual('新位置');
      expect(activeLocationText(['药箱', '抽屉'], '旧位置', 3)).assertEqual('分存 2 处：药箱；抽屉');
      expect(activeLocationText([], '旧位置', 0)).assertEqual('无现存库存');
      expect(activeLocationText([], '旧位置', 3)).assertEqual('现存批次位置未设置');
      expect(activeLocationText(undefined, '旧位置', 3)).assertEqual('旧位置');
    });
  });
}
