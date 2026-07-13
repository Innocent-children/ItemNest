import { describe, it, expect } from '@ohos/hypium';
import { shouldShowRecentSection } from '../../../main/ets/service/HomeSectionVisibility';

export default function homeSectionVisibilityTest() {
  describe('Home section visibility', () => {
    it('偏好关闭时隐藏最近添加栏', 0, () => {
      expect(shouldShowRecentSection(false)).assertFalse();
    });

    it('偏好开启时显示最近添加栏', 0, () => {
      expect(shouldShowRecentSection(true)).assertTrue();
    });
  });
}
