import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { cameraPicker, camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri, hash } from '@kit.CoreFileKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { Asset, uuid } from '../model/Models';
import { Repository } from '../data/Repository';

export class MediaService {
  private static pending: Promise<void> = Promise.resolve();
  private captures: Map<string, string> = new Map();
  context: common.UIAbilityContext;
  repository: Repository;
  constructor(context: common.UIAbilityContext, repository: Repository) { this.context = context; this.repository = repository; }
  path(id: string, thumbnail: boolean = false): string {
    const asset = this.repository.data.assets.find((value: Asset) => value.id === id);
    if (!asset) return '';
    const thumb = this.context.cacheDir + '/' + id + '.jpg';
    return thumbnail && fs.accessSync(thumb) ? thumb : this.context.filesDir + '/' + asset.relativePath;
  }
  uri(id: string, thumbnail: boolean = false): string {
    const path = this.path(id, thumbnail);
    return path ? fileUri.getUriFromPath(path) : '';
  }
  async pick(count: number): Promise<string[]> {
    const result = await new photoAccessHelper.PhotoViewPicker().select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: count });
    return result.photoUris;
  }
  async camera(): Promise<string[]> {
    const file = this.context.cacheDir + '/capture-' + uuid() + '.jpg';
    const handle = fs.openSync(file, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE); fs.closeSync(handle);
    try {
      const result = await cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK, saveUri: fileUri.getUriFromPath(file) });
      if (result.resultCode === 0 && result.resultUri) { this.captures.set(result.resultUri, file); return [result.resultUri]; }
      if (fs.accessSync(file)) fs.unlinkSync(file); return [];
    } catch (error) { if (fs.accessSync(file)) fs.unlinkSync(file); throw error as Error; }
  }
  importImage(uri: string): Promise<Asset> {
    const result = MediaService.pending.then(() => this.decodeImage(uri)).finally(() => { const capture = this.captures.get(uri); if (capture) { try { if (fs.accessSync(capture)) fs.unlinkSync(capture); } catch (_) {} this.captures.delete(uri); } });
    MediaService.pending = result.then(() => {}, () => {}); return result;
  }
  private async decodeImage(uri: string): Promise<Asset> {
    const input = await fs.open(uri, fs.OpenMode.READ_ONLY);
    let source: image.ImageSource | undefined;
    let pixels: image.PixelMap | undefined;
    let outputPath: string = '';
    let thumbnailPath: string = '';
    const packer = image.createImagePacker();
    try {
      if (fs.statSync(input.fd).size > 30 * 1024 * 1024) throw new Error('图片超过 30MB，请选择较小图片');
      source = image.createImageSource(input.fd);
      const info = await source.getImageInfo();
      if (info.size.width * info.size.height > 48000000) throw new Error('图片超过 4800 万像素，请选择较小图片');
      const ratio = Math.min(1, 2560 / Math.max(info.size.width, info.size.height));
      pixels = await source.createPixelMap({ desiredSize: { width: Math.max(1, Math.round(info.size.width * ratio)), height: Math.max(1, Math.round(info.size.height * ratio)) }, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      let orientation = '';
      try { orientation = await source.getImageProperty(image.PropertyKey.ORIENTATION); } catch (_) {}
      if (orientation.includes('270') || orientation === '8' || orientation === '5') await pixels.rotate(270);
      else if (orientation.includes('90') || orientation === '6' || orientation === '7') await pixels.rotate(90);
      else if (orientation.includes('180') || orientation === '3' || orientation === '4') await pixels.rotate(180);
      if (orientation === '2' || orientation === '4' || orientation === '5' || orientation === '7') await pixels.flip(true, false);
      const asset = new Asset(); asset.relativePath = 'assets/' + asset.id + '.jpg';
      outputPath = this.context.filesDir + '/' + asset.relativePath; thumbnailPath = this.context.cacheDir + '/' + asset.id + '.jpg';
      const dir = this.context.filesDir + '/assets'; if (!fs.accessSync(dir)) fs.mkdirSync(dir);
      const output = await fs.open(this.context.filesDir + '/' + asset.relativePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try { await packer.packToFile(pixels, output.fd, { format: 'image/jpeg', quality: 88 }); } finally { await fs.close(output); }
      const dimensions = await pixels.getImageInfo(); asset.width = dimensions.size.width; asset.height = dimensions.size.height;
      asset.byteSize = fs.statSync(this.context.filesDir + '/' + asset.relativePath).size;
      asset.sha256 = await hash.hash(this.context.filesDir + '/' + asset.relativePath, 'sha256');
      const existing = this.repository.data.assets.find((value: Asset) => value.sha256 === asset.sha256 && value.byteSize === asset.byteSize && fs.accessSync(this.context.filesDir + '/' + value.relativePath));
      if (existing) { fs.unlinkSync(this.context.filesDir + '/' + asset.relativePath); return existing; }
      const scale = Math.min(1, 480 / Math.max(asset.width, asset.height)); await pixels.scale(scale, scale);
      const thumb = await fs.open(this.context.cacheDir + '/' + asset.id + '.jpg', fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try { await packer.packToFile(pixels, thumb.fd, { format: 'image/jpeg', quality: 80 }); } finally { await fs.close(thumb); }
      this.repository.addAsset(asset); return asset;
    } catch (error) {
      [outputPath, thumbnailPath].filter((path: string) => !!path).forEach((path: string) => { try { if (fs.accessSync(path)) fs.unlinkSync(path); } catch (_) {} });
      const message = (error as Error).message;
      if (/ENOSPC|no space/i.test(message)) throw new Error('可用空间不足，请释放一些空间后继续保存');
      throw error as Error;
    } finally { await pixels?.release(); await source?.release(); await packer.release(); await fs.close(input); }
  }
  async recognize(id: string): Promise<string> {
    if (!await textRecognition.init()) throw new Error('文字识别暂未就绪，可以先保存照片');
    const source = image.createImageSource(this.path(id));
    let pixels: image.PixelMap | undefined;
    try {
      pixels = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      const result = await textRecognition.recognizeText({ pixelMap: pixels }); return result.value;
    } finally { await pixels?.release(); await source.release(); await textRecognition.release(); }
  }
}
