import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result } from '../../common/Result';

export interface ScanAdapter {
  scan(): Promise<Result<string | undefined>>;
}

export class UnavailableScanAdapter implements ScanAdapter {
  async scan(): Promise<Result<string | undefined>> {
    return failure<string | undefined>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '当前 SDK 未核验可用的条码/二维码相机扫码能力，请手动输入扫描结果'));
  }
}
