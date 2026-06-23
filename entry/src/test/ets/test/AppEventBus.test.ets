import { describe, it, expect } from '@ohos/hypium';
import { AppEventBus, DATA_REVISION_KEY, PREFERENCE_REVISION_KEY } from '../../../main/ets/common/AppEventBus';

function resetRevision(key: string): void {
  try {
    AppStorage.set<number>(key, 0);
  } catch (_) {
    AppStorage.setOrCreate<number>(key, 0);
  }
}

export default function appEventBusTest() {
  describe('AppEventBus', () => {
    it('数据变更会递增 revision 并通知已订阅页面', 0, () => {
      resetRevision(DATA_REVISION_KEY);
      let receivedCount = 0;
      let receivedRevision = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        receivedCount += 1;
        receivedRevision = AppEventBus.currentDataRevision();
      });

      const revision = AppEventBus.notifyDataChanged();

      expect(revision).assertEqual(1);
      expect(AppEventBus.currentDataRevision()).assertEqual(1);
      expect(receivedCount).assertEqual(1);
      expect(receivedRevision).assertEqual(1);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });

    it('取消订阅后不会继续触发页面刷新回调', 0, () => {
      resetRevision(DATA_REVISION_KEY);
      let receivedCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        receivedCount += 1;
      });

      AppEventBus.notifyDataChanged();
      AppEventBus.unsubscribeDataChanged(listenerId);
      AppEventBus.notifyDataChanged();

      expect(AppEventBus.currentDataRevision()).assertEqual(2);
      expect(receivedCount).assertEqual(1);
    });

    it('偏好 revision 与数据 revision 相互独立', 0, () => {
      resetRevision(DATA_REVISION_KEY);
      resetRevision(PREFERENCE_REVISION_KEY);
      let dataRefreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        dataRefreshCount += 1;
      });

      const preferenceRevision = AppEventBus.notifyPreferencesChanged();

      expect(preferenceRevision).assertEqual(1);
      expect(AppEventBus.currentPreferenceRevision()).assertEqual(1);
      expect(AppEventBus.currentDataRevision()).assertEqual(0);
      expect(dataRefreshCount).assertEqual(0);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });
  });
}
