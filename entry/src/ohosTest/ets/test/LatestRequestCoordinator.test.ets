import { describe, it, expect } from '@ohos/hypium';
import { LatestRequestCoordinator } from '../../../main/ets/common/LatestRequestCoordinator';

export default function latestRequestCoordinatorTest() {
  describe('LatestRequestCoordinator flow', () => {
    it('仅允许最新请求回写和结束 loading', 0, () => {
      const coordinator = new LatestRequestCoordinator();
      const oldRequestId = coordinator.begin();
      const currentRequestId = coordinator.begin();
      let loading = true;

      expect(coordinator.isCurrent(oldRequestId)).assertFalse();
      expect(coordinator.isCurrent(currentRequestId)).assertTrue();
      if (coordinator.isCurrent(oldRequestId)) {
        loading = false;
      }
      expect(loading).assertTrue();

      if (coordinator.isCurrent(currentRequestId)) {
        loading = false;
      }
      expect(loading).assertFalse();
    });

    it('显式作废会拒绝在途请求', 0, () => {
      const coordinator = new LatestRequestCoordinator();
      const requestId = coordinator.begin();

      coordinator.invalidate();

      expect(coordinator.isCurrent(requestId)).assertFalse();
    });
  });
}
