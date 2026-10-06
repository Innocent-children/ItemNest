import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';

const ASSET_DIRECTORY_NAME = 'itemnest-assets';

export class LocalAssetStorage {
  private readonly context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async copyFromPickerUri(sourceUri: string, assetId: string): Promise<Result<string>> {
    const targetPath = `${this.context.filesDir}/${ASSET_DIRECTORY_NAME}/${assetId}`;
    let sourceFile: fileIo.File | undefined = undefined;
    try {
      await this.ensureDirectory();
      // Picker 授权的是 URI，通过 open 获取描述符后才能复制到私有目录。
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      await fileIo.copyFile(sourceFile.fd, targetPath);
      return success<string>(targetPath);
    } catch (_) {
      await this.remove(targetPath);
      return failure<string>(new AppError(AppErrorCode.ASSET_STORAGE, '图片保存失败，请重新选择'));
    } finally {
      if (sourceFile !== undefined) {
        try {
          await fileIo.close(sourceFile);
        } catch (_) {
        }
      }
    }
  }

  async remove(localPath: string): Promise<Result<void>> {
    if (!this.isOwnedPath(localPath)) {
      return failure<void>(new AppError(AppErrorCode.ASSET_STORAGE, '本地图片路径无效'));
    }
    try {
      await fileIo.unlink(localPath);
      return success<void>(undefined);
    } catch (_) {
      return failure<void>(new AppError(AppErrorCode.ASSET_STORAGE, '本地图片清理失败，请稍后重试'));
    }
  }

  async listOwnedPaths(): Promise<Result<string[]>> {
    try {
      const names = await fileIo.listFile(`${this.context.filesDir}/${ASSET_DIRECTORY_NAME}`);
      const paths: string[] = [];
      for (const name of names) {
        const path = `${this.context.filesDir}/${ASSET_DIRECTORY_NAME}/${name}`;
        if (this.isOwnedPath(path)) {
          paths.push(path);
        }
      }
      return success(paths);
    } catch (_) {
      return success<string[]>([]);
    }
  }

  private isOwnedPath(path: string): boolean {
    const prefix = `${this.context.filesDir}/${ASSET_DIRECTORY_NAME}/`;
    const name = path.substring(prefix.length);
    return path.startsWith(prefix) && name.length > 0 && /^[A-Za-z0-9_-]+$/.test(name);
  }

  private async ensureDirectory(): Promise<void> {
    try {
      await fileIo.mkdir(`${this.context.filesDir}/${ASSET_DIRECTORY_NAME}`, true);
    } catch (_) {
      // 目录已经存在时继续复制；复制失败会在调用方转换成可操作错误。
    }
  }
}
