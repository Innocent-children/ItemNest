import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { AppIcon, AppIconState } from '../model/AppIcon';
import { AppIconAdapter } from './adapter/AppIconAdapter';

export class AppIconService {
  private readonly adapter: AppIconAdapter;
  constructor(adapter: AppIconAdapter) {
    this.adapter = adapter;
  }

  async getState(): Promise<Result<AppIconState>> {
    if (!this.adapter.isSupported()) {
      return success<AppIconState>({ supported: false, current: AppIcon.GIRL });
    }
    try {
      return success<AppIconState>({ supported: true, current: await this.adapter.getCurrent() });
    } catch (_) {
      return failure<AppIconState>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '读取桌面图标失败，请重试'));
    }
  }

  /**
   * 以系统实际使用的图标确认切换结果。
   */
  async select(icon: AppIcon): Promise<Result<AppIcon>> {
    if (!this.adapter.isSupported()) {
      return failure<AppIcon>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '升级至 HarmonyOS 7 后即可切换应用图标'));
    }
    try {
      if (await this.adapter.getCurrent() !== icon) {
        await this.adapter.setCurrent(icon);
      }
      if (await this.adapter.getCurrent() !== icon) {
        return failure<AppIcon>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '系统尚未应用所选图标，请重试'));
      }
    } catch (_) {
      return failure<AppIcon>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '切换桌面图标失败，请重试'));
    }
    return success(icon);
  }
}
