import { describe, it, expect } from '@ohos/hypium';
import { AppEventBus } from '../../../main/ets/common/AppEventBus';

export default function appEventBusTest() {
  describe('AppEventBus', () => {
    it('数据变更会递增 revision 并通知已订阅页面', 0, () => {
      const initialRevision = AppEventBus.currentDataRevision();
      let receivedCount = 0;
      let receivedRevision = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        receivedCount += 1;
        receivedRevision = AppEventBus.currentDataRevision();
      });

      const revision = AppEventBus.notifyDataChanged();

      expect(revision).assertEqual(initialRevision + 1);
      expect(AppEventBus.currentDataRevision()).assertEqual(initialRevision + 1);
      expect(receivedCount).assertEqual(1);
      expect(receivedRevision).assertEqual(initialRevision + 1);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });

    it('取消订阅后不会继续触发页面刷新回调', 0, () => {
      const initialRevision = AppEventBus.currentDataRevision();
      let receivedCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        receivedCount += 1;
      });

      AppEventBus.notifyDataChanged();
      AppEventBus.unsubscribeDataChanged(listenerId);
      AppEventBus.notifyDataChanged();

      expect(AppEventBus.currentDataRevision()).assertEqual(initialRevision + 2);
      expect(receivedCount).assertEqual(1);
    });

    it('偏好 revision 与数据 revision 相互独立', 0, () => {
      const initialDataRevision = AppEventBus.currentDataRevision();
      const initialPreferenceRevision = AppEventBus.currentPreferenceRevision();
      let dataRefreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        dataRefreshCount += 1;
      });

      const preferenceRevision = AppEventBus.notifyPreferencesChanged();

      expect(preferenceRevision).assertEqual(initialPreferenceRevision + 1);
      expect(AppEventBus.currentPreferenceRevision()).assertEqual(initialPreferenceRevision + 1);
      expect(AppEventBus.currentDataRevision()).assertEqual(initialDataRevision);
      expect(dataRefreshCount).assertEqual(0);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });
  });
}
