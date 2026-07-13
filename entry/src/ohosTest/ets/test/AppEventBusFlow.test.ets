import { describe, it, expect } from '@ohos/hypium';
import { AppEventBus } from '../../../main/ets/common/AppEventBus';

export default function appEventBusFlowTest() {
  describe('AppEventBus flow', () => {
    it('数据变更 revision 可驱动页面刷新并支持释放监听', 0, () => {
      const initialRevision = AppEventBus.currentDataRevision();
      let refreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        refreshCount += 1;
      });

      expect(AppEventBus.notifyDataChanged()).assertEqual(initialRevision + 1);
      AppEventBus.unsubscribeDataChanged(listenerId);
      expect(AppEventBus.notifyDataChanged()).assertEqual(initialRevision + 2);

      expect(AppEventBus.currentDataRevision()).assertEqual(initialRevision + 2);
      expect(refreshCount).assertEqual(1);
    });

    it('偏好 revision 不触发数据刷新监听', 0, () => {
      const initialDataRevision = AppEventBus.currentDataRevision();
      const initialPreferenceRevision = AppEventBus.currentPreferenceRevision();
      let refreshCount = 0;
      const listenerId = AppEventBus.subscribeDataChanged(() => {
        refreshCount += 1;
      });

      expect(AppEventBus.notifyPreferencesChanged()).assertEqual(initialPreferenceRevision + 1);

      expect(AppEventBus.currentDataRevision()).assertEqual(initialDataRevision);
      expect(AppEventBus.currentPreferenceRevision()).assertEqual(initialPreferenceRevision + 1);
      expect(refreshCount).assertEqual(0);
      AppEventBus.unsubscribeDataChanged(listenerId);
    });
  });
}
