import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describe, it, expect } from '@ohos/hypium';
import { SystemScanAdapter } from '../../../main/ets/service/adapter/ScanAdapter';

export default function scanAdapterTest() {
  describe('Scan adapter', () => {
    it('返回扫码原文', 0, async () => {
      const adapter = new SystemScanAdapter(async (_context: Context): Promise<string> => '6901234567890');
      const result = await adapter.scan({} as Context);
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData()).assertEqual('6901234567890');
      }
    });

    it('取消扫码不报错', 0, async () => {
      const adapter = new SystemScanAdapter(async (_context: Context): Promise<string> => {
        const error = new Error('cancel');
        (error as BusinessError).code = 1000500002;
        throw error;
      });
      const result = await adapter.scan({} as Context);
      expect(result.ok).assertTrue();
      if (result.ok) {
        expect(result.getData()).assertUndefined();
      }
    });

    it('扫码能力异常提示手工输入', 0, async () => {
      const adapter = new SystemScanAdapter(async (_context: Context): Promise<string> => {
        const error = new Error('unavailable');
        (error as BusinessError).code = 1000500001;
        throw error;
      });
      const result = await adapter.scan({} as Context);
      expect(result.ok).assertFalse();
      if (!result.ok) {
        expect(result.getError().message.indexOf('手动输入') >= 0).assertTrue();
      }
    });
  });
}
