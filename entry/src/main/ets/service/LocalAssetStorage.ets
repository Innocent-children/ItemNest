import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';

const ASSET_DIRECTORY_NAME = 'itemtrace-assets';

export class LocalAssetStorage {
  private readonly context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async copyFromPickerUri(sourceUri: string, assetId: string): Promise<Result<string>> {
    const targetPath = `${this.context.filesDir}/${ASSET_DIRECTORY_NAME}/${assetId}`;
    try {
      await this.ensureDirectory();
      await fileIo.copyFile(sourceUri, targetPath);
      return success<string>(targetPath);
    } catch (_) {
      return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '图片保存失败，请重新选择'));
    }
  }

  async remove(localPath: string): Promise<Result<void>> {
    try {
      await fileIo.unlink(localPath);
      return success<void>(undefined);
    } catch (_) {
      return failure<void>(new AppError(AppErrorCode.ASSET_STORAGE, '本地图片清理失败，请稍后重试'));
    }
  }

  private async ensureDirectory(): Promise<void> {
    try {
      await fileIo.mkdir(`${this.context.filesDir}/${ASSET_DIRECTORY_NAME}`, true);
    } catch (_) {
      // 目录已经存在时继续复制；复制失败会在调用方转换成可操作错误。
    }
  }
}
