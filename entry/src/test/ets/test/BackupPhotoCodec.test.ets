import { describe, it, expect } from '@ohos/hypium';
import { BackupPhotoCodec } from '../../../main/ets/common/BackupPhotoCodec';
import { MAX_PHOTO_BYTES } from '../../../main/ets/common/PortableBackupValidation';

export default function backupPhotoCodecTest() {
  describe('Backup photo codec', () => {
    it('支持备份照片的 PNG 文件头', 0, () => {
      const bytes = new Uint8Array([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52]);
      const codec = new BackupPhotoCodec();
      expect(codec.isSupportedImage(bytes)).assertTrue();
    });

    it('拒绝伪装图片与超过单张大小上限的内容', 0, () => {
      const codec = new BackupPhotoCodec();
      expect(codec.isSupportedImage(new Uint8Array(16))).assertFalse();
      const oversized = new Uint8Array(MAX_PHOTO_BYTES + 1);
      oversized.set([0x89, 0x50, 0x4E, 0x47]);
      expect(codec.isSupportedImage(oversized)).assertFalse();
    });
  });
}
