import { Context } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo, picker } from '@kit.CoreFileKit';

export class LabelImageService {
  async save(context: Context, pixels: image.PixelMap, name: string): Promise<boolean> {
    const packer = image.createImagePacker();
    try {
      const bytes = await packer.packToData(pixels, { format: 'image/png', quality: 100 });
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`${name.replace(/[\\/:*?"<>|]/g, '-').slice(0, 60) || '收纳标签'}.png`];
      options.fileSuffixChoices = ['收纳标签图片|.png'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) { return false; }
      const file = await fileIo.open(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        let written = 0;
        while (written < bytes.byteLength) {
          const count = await fileIo.write(file.fd, bytes.slice(written));
          if (count <= 0) { throw new Error('无法完整保存标签图片'); }
          written += count;
        }
      } finally { await fileIo.close(file); }
      return true;
    } finally { await packer.release(); }
  }
}
