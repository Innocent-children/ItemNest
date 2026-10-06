import { describe, expect, it } from '@ohos/hypium';
import { AppIcon } from '../../../main/ets/model/AppIcon';
import { AppIconService } from '../../../main/ets/service/AppIconService';
import { AppIconAdapter } from '../../../main/ets/service/adapter/AppIconAdapter';
import { AppIconPreferencePort } from '../../../main/ets/data/repository/PreferenceRepository';
import { failure, Result, success } from '../../../main/ets/common/Result';
import { AppError, AppErrorCode } from '../../../main/ets/common/AppError';

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

class FakeIconPreferences implements AppIconPreferencePort {
  completed: boolean = false;
  readFails: boolean = false;
  saveFails: boolean = false;
  saveCalls: number = 0;

  async isIconSelectionCompleted(): Promise<Result<boolean>> {
    return this.readFails ? failure<boolean>(new AppError(AppErrorCode.PREFERENCE_READ, 'read failed')) : success(this.completed);
  }

  async completeIconSelection(): Promise<Result<void>> {
    this.saveCalls++;
    if (this.saveFails) {
      return failure<void>(new AppError(AppErrorCode.PREFERENCE_WRITE, 'save failed'));
    }
    this.completed = true;
    return success<void>(undefined);
  }
}

export default function appIconServiceTest() {
  describe('App icon selection', () => {
    it('首次选择默认女孩后重建服务仍记住已完成', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      const service = new AppIconService(adapter, preferences);
      expect((await service.needsInitialSelection()).getData()).assertTrue();
      expect((await service.select(AppIcon.GIRL)).ok).assertTrue();
      expect(adapter.setCalls).assertEqual(0);
      expect((await new AppIconService(adapter, preferences).needsInitialSelection()).getData()).assertFalse();
      adapter.readFails = true;
      expect((await service.needsInitialSelection()).getData()).assertFalse();
    });

    it('两个图标可双向切换并以系统图标显示当前选择', 0, async () => {
      const adapter = new FakeIconAdapter();
      const service = new AppIconService(adapter, new FakeIconPreferences());
      expect((await service.select(AppIcon.BUDDY)).getData()).assertEqual(AppIcon.BUDDY);
      expect((await service.getState()).getData().current).assertEqual(AppIcon.BUDDY);
      expect((await service.select(AppIcon.GIRL)).getData()).assertEqual(AppIcon.GIRL);
      expect((await service.getState()).getData().current).assertEqual(AppIcon.GIRL);
      expect(adapter.setCalls).assertEqual(2);
    });

    it('系统切换失败不完成引导且允许重试', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      const service = new AppIconService(adapter, preferences);
      adapter.switchFails = true;
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(preferences.completed).assertFalse();
      expect(preferences.saveCalls).assertEqual(0);
      expect(adapter.current).assertEqual(AppIcon.GIRL);
      adapter.switchFails = false;
      expect((await service.select(AppIcon.BUDDY)).ok).assertTrue();
    });

    it('系统未实际应用时不报告成功', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      adapter.ignoreSwitch = true;
      expect((await new AppIconService(adapter, preferences).select(AppIcon.BUDDY)).ok).assertFalse();
      expect(preferences.completed).assertFalse();
      expect(preferences.saveCalls).assertEqual(0);
    });

    it('系统已切换而偏好保存失败时重试只补存完成标记', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      const service = new AppIconService(adapter, preferences);
      preferences.saveFails = true;
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(adapter.current).assertEqual(AppIcon.BUDDY);
      expect(preferences.completed).assertFalse();
      preferences.saveFails = false;
      expect((await service.select(AppIcon.BUDDY)).ok).assertTrue();
      expect(adapter.setCalls).assertEqual(1);
      expect(preferences.completed).assertTrue();
    });

    it('旧系统不会调用动态图标接口或完成首次选择', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      adapter.supported = false;
      const service = new AppIconService(adapter, preferences);
      expect((await service.getState()).getData().supported).assertFalse();
      expect((await service.needsInitialSelection()).getData()).assertFalse();
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(adapter.getCalls).assertEqual(0);
      expect(preferences.saveCalls).assertEqual(0);
    });

    it('偏好或系统读取失败不能误认为用户已完成选择', 0, async () => {
      const adapter = new FakeIconAdapter();
      const preferences = new FakeIconPreferences();
      const service = new AppIconService(adapter, preferences);
      preferences.readFails = true;
      expect((await service.needsInitialSelection()).ok).assertFalse();
      preferences.readFails = false;
      adapter.readFails = true;
      expect((await service.getState()).ok).assertFalse();
      expect((await service.select(AppIcon.BUDDY)).ok).assertFalse();
      expect(preferences.completed).assertFalse();
    });
  });
}
