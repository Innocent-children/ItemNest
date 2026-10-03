import { Context } from '@kit.AbilityKit';
import { scanBarcode } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';

export interface ScanAdapter {
  scan(context: Context): Promise<Result<string | undefined>>;
}

export class SystemScanAdapter implements ScanAdapter {
  private readonly startScan: (context: Context) => Promise<string>;

  constructor(startScan: (context: Context) => Promise<string> = async (context: Context): Promise<string> => {
    const result = await scanBarcode.startScanForResult(context);
    return result.originalValue;
  }) {
    this.startScan = startScan;
  }

  async scan(context: Context): Promise<Result<string | undefined>> {
    try {
      return success<string | undefined>(await this.startScan(context));
    } catch (error) {
      if ((error as BusinessError).code === 1000500002) {
        return success<string | undefined>(undefined);
      }
      return failure<string | undefined>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '扫码暂不可用，请手动输入条码或二维码文本'));
    }
  }
}
