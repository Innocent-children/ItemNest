import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppError, AppErrorCode } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';

export class TextRecognitionAdapter {
  private running: boolean = false;

  async recognize(uri: string): Promise<Result<string>> {
    if (this.running) {
      return failure(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '正在识别，请稍候'));
    }
    this.running = true;
    let file: fileIo.File | undefined;
    let source: image.ImageSource | undefined;
    let pixels: image.PixelMap | undefined;
    let initialized = false;
    try {
      file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      const info = await source.getImageInfo();
      const scale = Math.min(1, 2400 / Math.max(info.size.width, info.size.height));
      pixels = await source.createPixelMap({ desiredSize: {
        width: Math.round(info.size.width * scale), height: Math.round(info.size.height * scale)
      } });
      initialized = await textRecognition.init();
      if (!initialized) { throw new Error('unavailable'); }
      const result = await textRecognition.recognizeText({ pixelMap: pixels }, { isDirectionDetectionSupported: true });
      return success(result.value);
    } catch (_) {
      return failure(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE,
        '文字识别暂不可用，请确认设备支持该能力，或手动填写；也可以换一张清晰的包装照片重试'));
    } finally {
      if (initialized) { try { await textRecognition.release(); } catch (_) {} }
      if (pixels !== undefined) { try { await pixels.release(); } catch (_) {} }
      if (source !== undefined) { try { await source.release(); } catch (_) {} }
      if (file !== undefined) { try { await fileIo.close(file); } catch (_) {} }
      this.running = false;
    }
  }
}
