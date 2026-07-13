import { describe, it, expect } from '@ohos/hypium';
import { LatestRequestCoordinator } from '../../../main/ets/common/LatestRequestCoordinator';

export default function latestRequestCoordinatorTest() {
  describe('LatestRequestCoordinator', () => {
    it('新请求会作废旧请求并保持自身有效', 0, () => {
      const coordinator = new LatestRequestCoordinator();
      const firstRequestId = coordinator.begin();
      const secondRequestId = coordinator.begin();

      expect(coordinator.isCurrent(firstRequestId)).assertFalse();
      expect(coordinator.isCurrent(secondRequestId)).assertTrue();
    });

    it('显式作废后当前请求不能再回写或结束 loading', 0, () => {
      const coordinator = new LatestRequestCoordinator();
      const requestId = coordinator.begin();

      coordinator.invalidate();

      expect(coordinator.isCurrent(requestId)).assertFalse();
    });

    it('旧请求完成时不会影响仍在进行的新请求', 0, () => {
      const coordinator = new LatestRequestCoordinator();
      const oldRequestId = coordinator.begin();
      const currentRequestId = coordinator.begin();
      let loading = true;

      if (coordinator.isCurrent(oldRequestId)) {
        loading = false;
      }
      expect(loading).assertTrue();

      if (coordinator.isCurrent(currentRequestId)) {
        loading = false;
      }
      expect(loading).assertFalse();
    });
  });
}
