import { ExpiryStatus } from '../../../main/ets/model/ExpiryStatus';
import { describe, it, expect } from '@ohos/hypium';
import { CategoryRecord } from '../../../main/ets/model/Category';
import { ItemUnit } from '../../../main/ets/model/Item';
import { activeCategoryNames, activeLocationText, refreshedUnit, expiryDescription } from '../../../main/ets/service/ItemFlowPresentation';

function category(name: string, active: boolean, systemPreset: boolean): CategoryRecord {
  return { id: name, name: name, active: active, systemPreset: systemPreset, createdAt: 1, updatedAt: 1 };
}

export default function pageFlowPolicyTest() {
  describe('Item flow presentation', () => {
    it('到期提示区分今天明天和过期天数', 0, () => {
      const now = new Date(2026, 9, 6, 23, 59);
      expect(expiryDescription(ExpiryStatus.DUE_SOON, '2026-10-06', now)).assertEqual('今天到期');
      expect(expiryDescription(ExpiryStatus.DUE_SOON, '2026-10-07', now)).assertEqual('明天到期');
      expect(expiryDescription(ExpiryStatus.DUE_SOON, '2026-10-09', now)).assertEqual('3 天后到期');
      expect(expiryDescription(ExpiryStatus.EXPIRED, '2026-10-04', now)).assertEqual('已过期 2 天');
    });

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
      expect(activeLocationText([], '旧位置', 0)).assertEqual('已经用完');
      expect(activeLocationText([], '旧位置', 3)).assertEqual('还没填写存放位置');
      expect(activeLocationText(undefined, '旧位置', 3)).assertEqual('旧位置');
    });
  });
}
