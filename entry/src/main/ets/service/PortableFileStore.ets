import { Context } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { AppError, AppErrorCode } from '../common/AppError';
import { MAX_BACKUP_BYTES, MAX_PHOTO_BYTES } from '../common/PortableBackupValidation';
import { failure, Result, success } from '../common/Result';

export class PortableFileStore {
  private readonly context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async selectBackup(context: Context): Promise<Result<string | undefined>> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const appName = context.resourceManager.getStringSync($r('app.string.app_name').id);
      options.fileSuffixFilters = [`${appName} 备份|.json`];
      const uris = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) {
        return success<string | undefined>(undefined);
      }
      const bytes = await this.readBytes(uris[0], MAX_BACKUP_BYTES);
      return success<string | undefined>(new util.TextDecoder('utf-8').decodeToString(bytes));
    } catch (_) {
      return failure<string | undefined>(new AppError(AppErrorCode.ASSET_STORAGE, '无法读取备份文件，请选择有效的本地 JSON 文件'));
    }
  }

  async saveBackup(context: Context, text: string, beforeWrite?: () => void): Promise<Result<boolean>> {
    try {
      const options = new picker.DocumentSaveOptions();
      const appName = context.resourceManager.getStringSync($r('app.string.app_name').id);
      options.newFileNames = [`${appName}-${Date.now()}.json`];
      options.fileSuffixChoices = [`${appName} 备份|.json`];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        return success<boolean>(false);
      }
      if (beforeWrite !== undefined) { beforeWrite(); }
      const bytes = new util.TextEncoder().encodeInto(text);
      await this.writeBytes(uris[0], bytes, false);
      return success<boolean>(true);
    } catch (_) {
      return failure<boolean>(new AppError(AppErrorCode.ASSET_STORAGE, '无法保存备份文件，请更换位置重试'));
    }
  }

  async readOwnedPhoto(path: string): Promise<Uint8Array> {
    if (!this.isOwnedPhotoPath(path)) {
      throw new AppError(AppErrorCode.ASSET_STORAGE, '图片路径无效');
    }
    return this.readBytes(path, MAX_PHOTO_BYTES);
  }

  async writeOwnedPhoto(assetId: string, bytes: Uint8Array): Promise<string> {
    if (!this.safeAssetId(assetId) || bytes.length === 0 || bytes.length > MAX_PHOTO_BYTES) {
      throw new AppError(AppErrorCode.ASSET_STORAGE, '图片内容无效');
    }
    const directory = `${this.context.filesDir}/itemnest-assets`;
    try {
      await fileIo.mkdir(directory, true);
    } catch (_) {
    }
    const path = `${directory}/${assetId}`;
    try {
      await this.writeBytes(path, bytes, true);
    } catch (_) {
      try { await fileIo.unlink(path); } catch (_) {}
      throw new AppError(AppErrorCode.ASSET_STORAGE, '保存恢复照片失败');
    }
    return path;
  }

  async writeSafetyBackup(text: string): Promise<string> {
    const path = `${this.context.filesDir}/itemnest-before-restore-${Date.now()}-${Math.floor(Math.random() * 1000000)}.json`;
    const temporary = `${path}.tmp`;
    try {
      await this.writeBytes(temporary, new util.TextEncoder().encodeInto(text), true);
      await fileIo.rename(temporary, path);
    } catch (_) {
      try { await fileIo.unlink(temporary); } catch (_) {}
      throw new AppError(AppErrorCode.ASSET_STORAGE, '写入恢复前备份失败');
    }
    await this.pruneSafetyBackups();
    return path;
  }

  async saveSafetyBackup(context: Context): Promise<Result<boolean>> {
    try {
      const paths = await this.listSafetyPaths();
      if (paths.length === 0) {
        return failure<boolean>(new AppError(AppErrorCode.NOT_FOUND, '尚无恢复前备份'));
      }
      const bytes = await this.readBytes(paths[0], MAX_BACKUP_BYTES);
      return this.saveBackup(context, new util.TextDecoder('utf-8').decodeToString(bytes));
    } catch (_) {
      return failure<boolean>(new AppError(AppErrorCode.NOT_FOUND, '尚无恢复前备份'));
    }
  }

  private async listSafetyPaths(): Promise<string[]> {
    const names = await fileIo.listFile(this.context.filesDir);
    const backups = names.filter(name => /^itemnest-before-restore-[0-9]+-[0-9]+\.json$/.test(name));
    backups.sort().reverse();
    return backups.map(name => `${this.context.filesDir}/${name}`);
  }

  private async pruneSafetyBackups(): Promise<void> {
    try {
      const paths = await this.listSafetyPaths();
      for (let index = 3; index < paths.length; index++) {
        await fileIo.unlink(paths[index]);
      }
    } catch (_) {
      // 安全备份已写入；旧文件清理失败不阻断恢复。
    }
  }

  async removeOwnedPhoto(path: string): Promise<void> {
    if (this.isOwnedPhotoPath(path)) {
      await fileIo.unlink(path);
    }
  }

  private isOwnedPhotoPath(path: string): boolean {
    const prefix = `${this.context.filesDir}/itemnest-assets/`;
    return path.startsWith(prefix) && this.safeAssetId(path.substring(prefix.length));
  }

  private safeAssetId(id: string): boolean {
    return id.length > 0 && id.length <= 128 && /^[A-Za-z0-9_-]+$/.test(id);
  }

  private async readBytes(path: string, limit: number): Promise<Uint8Array> {
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const size = (await fileIo.stat(file.fd)).size;
      if (size < 0 || size > limit) {
        throw new AppError(AppErrorCode.VALIDATION, '文件大小超过上限');
      }
      const bytes = new Uint8Array(size);
      let read = 0;
      while (read < size) {
        const buffer = new ArrayBuffer(Math.min(64 * 1024, size - read));
        const count = await fileIo.read(file.fd, buffer);
        if (count <= 0) {
          throw new AppError(AppErrorCode.ASSET_STORAGE, '文件读取不完整');
        }
        bytes.set(new Uint8Array(buffer, 0, count), read);
        read += count;
      }
      return bytes;
    } finally {
      await fileIo.close(file);
    }
  }

  private async writeBytes(path: string, bytes: Uint8Array, create: boolean): Promise<void> {
    const mode = fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC |
      (create ? fileIo.OpenMode.CREATE : 0);
    const file = await fileIo.open(path, mode);
    try {
      let written = 0;
      while (written < bytes.length) {
        const chunk = bytes.slice(written, Math.min(bytes.length, written + 64 * 1024));
        const count = await fileIo.write(file.fd, chunk.buffer);
        if (count <= 0) {
          throw new AppError(AppErrorCode.ASSET_STORAGE, '文件写入不完整');
        }
        written += count;
      }
      if (create) {
        await fileIo.fsync(file.fd);
      }
    } finally {
      await fileIo.close(file);
    }
  }
}
