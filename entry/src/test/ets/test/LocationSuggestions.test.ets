import { describe, it, expect } from '@ohos/hypium';
import { LocationRecord } from '../../../main/ets/model/Location';
import { buildLocationSuggestions } from '../../../main/ets/service/LocationSuggestions';
import { planLocationUsage } from '../../../main/ets/service/LocationUsagePolicy';

function location(path: string, lastUsedAt?: number, active: boolean = true): LocationRecord {
  return { id: `id-${path}`, name: path, path: path, active: active,
    createdAt: 1, updatedAt: 1000, lastUsedAt: lastUsedAt };
}

export default function locationSuggestionsTest() {
  describe('Location suggestions and usage', () => {
    it('没有历史时提供预设且不自动写入用户位置', 0, () => {
      const locations: LocationRecord[] = [];
      const suggestions = buildLocationSuggestions(locations, '');
      expect(suggestions.hasHistory).assertFalse();
      expect(suggestions.recentPaths.length).assertEqual(0);
      expect(suggestions.presetPaths.includes('客厅')).assertTrue();
      expect(suggestions.presetPaths.includes('厨房')).assertTrue();
      expect(locations.length).assertEqual(0);
    });

    it('最近位置按使用时间排序并限制六项，位置改名时间不影响顺序', 0, () => {
      const locations: LocationRecord[] = [];
      for (let index = 1; index <= 8; index++) { locations.push(location(`位置${index}`, index)); }
      locations[0].updatedAt = 99999;
      const suggestions = buildLocationSuggestions(locations, '');
      expect(suggestions.recentPaths.length).assertEqual(6);
      expect(suggestions.recentPaths[0]).assertEqual('位置8');
      expect(suggestions.recentPaths[5]).assertEqual('位置3');
      expect(suggestions.hasHistory).assertTrue();
    });

    it('按路径任意片段筛选并保留未使用过的管理位置', 0, () => {
      const locations = [location('厨房 / 冰箱 / 冷藏层', 20), location('客厅', 10), location('办公室 / 冰箱')];
      const suggestions = buildLocationSuggestions(locations, ' 冰箱 ');
      expect(suggestions.recentPaths.join(',')).assertEqual('厨房 / 冰箱 / 冷藏层');
      expect(suggestions.savedPaths.join(',')).assertEqual('办公室 / 冰箱');
      expect(suggestions.presetPaths.length).assertEqual(0);
      expect(buildLocationSuggestions(locations, '不存在的位置').recentPaths.length).assertEqual(0);
    });

    it('历史、管理位置与预设去重，停用位置和子路径不再推荐', 0, () => {
      const locations = [location('客厅', 20), location('客厅', 10), location('厨房', undefined, false),
        location('厨房 / 冰箱', 30), location('卧室')];
      const suggestions = buildLocationSuggestions(locations, '');
      expect(suggestions.recentPaths.join(',')).assertEqual('客厅');
      expect(suggestions.savedPaths.join(',')).assertEqual('卧室');
      expect(suggestions.presetPaths.includes('客厅')).assertFalse();
      expect(suggestions.presetPaths.includes('厨房')).assertFalse();
      expect(suggestions.presetPaths.includes('卧室')).assertFalse();
    });

    it('重复使用同一位置保留身份、更新时间和原数组，只刷新最近使用时间', 0, () => {
      const original = location('客厅', 10);
      const changes = planLocationUsage([original], ' 客厅 ', 20);
      expect(changes.length).assertEqual(1);
      expect(changes[0].id).assertEqual(original.id);
      expect(changes[0].lastUsedAt).assertEqual(20);
      expect(changes[0].updatedAt).assertEqual(1000);
      expect(original.lastUsedAt).assertEqual(10);
      expect(planLocationUsage(changes, '客厅', 15)[0].lastUsedAt).assertEqual(20);
    });

    it('完整路径建立正确层级且仅完整路径进入最近使用', 0, () => {
      const changes = planLocationUsage([], '厨房 / 冰箱 / 冷藏层', 30);
      expect(changes.length).assertEqual(3);
      expect(changes[0].path).assertEqual('厨房');
      expect(changes[1].parentId).assertEqual(changes[0].id);
      expect(changes[2].parentId).assertEqual(changes[1].id);
      expect(changes[2].name).assertEqual('冷藏层');
      expect(changes[0].lastUsedAt === undefined).assertTrue();
      expect(buildLocationSuggestions(changes, '').recentPaths.join(',')).assertEqual('厨房 / 冰箱 / 冷藏层');
    });

    it('已有完整路径补齐父级时保留原身份和使用时间', 0, () => {
      const existing = location('厨房 / 冰箱', 10);
      const changes = planLocationUsage([existing], existing.path, 20);
      expect(changes.length).assertEqual(2);
      expect(changes[1].id).assertEqual(existing.id);
      expect(changes[1].name).assertEqual('冰箱');
      expect(changes[1].parentId).assertEqual(changes[0].id);
    });

    it('空白和超长路径不记住，也不重新启用停用位置', 0, () => {
      expect(planLocationUsage([], undefined, 20).length).assertEqual(0);
      expect(planLocationUsage([], '  ', 20).length).assertEqual(0);
      expect(planLocationUsage([], '柜'.repeat(201), 20).length).assertEqual(0);
      const disabled = location('厨房', 10, false);
      expect(planLocationUsage([disabled], '厨房 / 冰箱', 20).length).assertEqual(0);
      expect(disabled.active).assertFalse();
    });
  });
}
