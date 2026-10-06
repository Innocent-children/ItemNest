import { describe, expect, it } from '@ohos/hypium';
import { AppIcon } from '../../../main/ets/model/AppIcon';
import { AppIconService } from '../../../main/ets/service/AppIconService';
import { AppIconAdapter } from '../../../main/ets/service/adapter/AppIconAdapter';

class FakeIconAdapter implements AppIconAdapter {
  supported: boolean = true;
  current: AppIcon = AppIcon.GIRL;
  setCalls: number = 0;
  getCalls: number = 0;
  readFails: boolean = false;
  switchFails: boolean = false;
  ignoreSwitch: boolean = false;

  isSupported(): boolean { return this.supported; }

  async getCurrent(): Promise<AppIcon> {
    this.getCalls++;
    if (this.readFails) { throw new Error('read failed'); }
    return this.current;
  }

  async setCurrent(icon: AppIcon): Promise<void> {
    this.setCalls++;
    if (this.switchFails) { throw new Error('switch failed'); }
    if (!this.ignoreSwitch) { this.current = icon; }
  }
}

export default function appIconServiceTest() {
  describe('App icon selection', () => {
    it('使用当前图标不重复切换系统图标', 0, async () => {
      const adapter = new FakeIconAdapter();
      expect((await new AppIconService(adapter).select(AppIcon.GIRL)).ok).assertTrue();
      expect(adapter.setCalls).assertEqual(0);
    });

    it('两个图标可双向切换并以系统状态确认结果', 0, async () => {
      const adapter = new FakeIconAdapter();
      const service = new AppIconService(adapter);
      expect((await service.select(AppIcon.BUDDY)).getData()).assertEqual(AppIcon.BUDDY);
      expect((await service.getState()).getData().current).assertEqual(AppIcon.BUDDY);
      expect((await service.select(AppIcon.GIRL)).getData()).assertEqual(AppIcon.GIRL);
      expect(adapter.setCalls).assertEqual(2);
    });

    it('切换失败后仍可重新选择，未应用的图标不报告成功', 0, async () => {
      const adapter = new FakeIconAdapter();
      const service = new AppIconService(adapter);
      adapter.switchFails = true;
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(adapter.current).assertEqual(AppIcon.GIRL);
      adapter.switchFails = false;
      adapter.ignoreSwitch = true;
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      adapter.ignoreSwitch = false;
      expect((await service.select(AppIcon.BUDDY)).ok).assertTrue();
    });

    it('不支持换图标或读取失败时返回明确失败', 0, async () => {
      const adapter = new FakeIconAdapter();
      const service = new AppIconService(adapter);
      adapter.supported = false;
      expect((await service.getState()).getData().supported).assertFalse();
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(adapter.getCalls).assertEqual(0);
      adapter.supported = true;
      adapter.readFails = true;
      expect((await service.getState()).ok).assertFalse();
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
    });
  });
}
