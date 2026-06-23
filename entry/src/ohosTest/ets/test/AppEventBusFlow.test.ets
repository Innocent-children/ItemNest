import { describe, it, expect } from '@ohos/hypium';
import { AppEventBus, DATA_REVISION_KEY, PREFERENCE_REVISION_KEY } from '../../../main/ets/common/AppEventBus';

function resetRevision(key: string): void {
  try {
    AppStorage.set<number>(key, 0);
  } catch (_) {
    AppStorage.setOrCreate<number>(key, 0);
  }
}

export default function appEventBusFlowTest() {
  describe('AppEventBus flow', () => {
    it('数据变更 revision 可驱动页面刷新并支持释放监听', 0, () => {
      resetRevision(DATA_REVISION_KEY);
      let refreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        refreshCount += 1;
      });

      expect(AppEventBus.notifyDataChanged()).assertEqual(1);
      AppEventBus.unsubscribeDataChanged(listenerId);
      expect(AppEventBus.notifyDataChanged()).assertEqual(2);

      expect(AppEventBus.currentDataRevision()).assertEqual(2);
      expect(refreshCount).assertEqual(1);
    });

    it('偏好 revision 不触发数据刷新监听', 0, () => {
      resetRevision(DATA_REVISION_KEY);
      resetRevision(PREFERENCE_REVISION_KEY);
      let refreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        refreshCount += 1;
      });

      expect(AppEventBus.notifyPreferencesChanged()).assertEqual(1);

      expect(AppEventBus.currentDataRevision()).assertEqual(0);
      expect(AppEventBus.currentPreferenceRevision()).assertEqual(1);
      expect(refreshCount).assertEqual(0);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });
  });
}
