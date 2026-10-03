import { util } from '@kit.ArkTS';
import { MAX_PHOTO_BYTES } from './PortableBackupValidation';

export class BackupPhotoCodec {
  encode(bytes: Uint8Array): string {
    if (!this.isSupportedImage(bytes)) {
      throw new Error('Invalid backup photo');
    }
    return new util.Base64Helper().encodeToStringSync(bytes);
  }

  decode(text: string): Uint8Array {
    const bytes = new util.Base64Helper().decodeSync(text);
    if (!this.isSupportedImage(bytes)) {
      throw new Error('Invalid backup photo');
    }
    return bytes;
  }

  isSupportedImage(bytes: Uint8Array): boolean {
    return bytes.length >= 12 && bytes.length <= MAX_PHOTO_BYTES &&
      ((bytes[0] === 0xFF && bytes[1] === 0xD8) ||
      (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) ||
      (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
        bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) ||
      (bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70 &&
        ((bytes[8] === 0x68 && bytes[9] === 0x65 && bytes[10] === 0x69) ||
          (bytes[8] === 0x6D && bytes[9] === 0x69 && bytes[10] === 0x66 && bytes[11] === 0x31) ||
          (bytes[8] === 0x61 && bytes[9] === 0x76 && bytes[10] === 0x69 && bytes[11] === 0x66))));
  }
}
