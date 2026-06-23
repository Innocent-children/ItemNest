import { describe, it, expect } from '@ohos/hypium';
import { shouldShowRecentSection } from '../../../main/ets/service/HomeSectionVisibility';

export default function homeSectionVisibilityTest() {
  describe('HomeSectionVisibility', () => {
    it('偏好关闭但存在最近添加物品时仍显示最近添加栏', 0, () => {
      expect(shouldShowRecentSection(false, 1)).assertTrue();
    });

    it('偏好关闭且没有最近添加物品时隐藏最近添加栏', 0, () => {
      expect(shouldShowRecentSection(false, 0)).assertFalse();
    });

    it('偏好开启时即使为空也显示最近添加栏', 0, () => {
      expect(shouldShowRecentSection(true, 0)).assertTrue();
    });
  });
}
