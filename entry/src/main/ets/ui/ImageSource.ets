import { fileUri } from '@kit.CoreFileKit';

/**
 * 数据库保留磁盘路径供文件操作使用，Image 读取私有文件时需要文件 URI。
 */
export function localImageSource(path: string): string {
  return path.startsWith('/') ? fileUri.getUriFromPath(path) : path;
}
