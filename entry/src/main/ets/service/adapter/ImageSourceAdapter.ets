import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';

export interface ImageSourceAdapter {
  selectFromAlbum(): Promise<Result<string | undefined>>;
  captureWithSystemPicker(): Promise<Result<string | undefined>>;
}

export class SystemImageSourceAdapter implements ImageSourceAdapter {
  async selectFromAlbum(): Promise<Result<string | undefined>> {
    return this.select(false);
  }

  async captureWithSystemPicker(): Promise<Result<string | undefined>> {
    return this.select(true);
  }

  private async select(enablePhotoTaking: boolean): Promise<Result<string | undefined>> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isPhotoTakingSupported = enablePhotoTaking;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      return success<string | undefined>(result.photoUris.length === 0 ? undefined : result.photoUris[0]);
    } catch (_) {
      return failure<string | undefined>(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '系统相册选择器暂不可用，请稍后重试'));
    }
  }
}
