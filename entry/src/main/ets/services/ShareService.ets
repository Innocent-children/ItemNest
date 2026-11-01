import { common, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { uuid } from '../model/Models';

export class IncomingShare {
  id: string = uuid();
  files: string[] = [];
  count: number = 0;
  errors: number = 0;
}
export class ShareService {
  /**
   * 临时 URI 只在接收时使用；复制完成后才通知界面，避免外部授权失效影响草稿。
   */
  static async receive(context: common.Context, want: Want): Promise<void> {
    const share = new IncomingShare();
    const data = await systemShare.getSharedData(want);
    const records = data.getRecords(); share.count = records.length;
    if (!records.length || records.length > 9) throw new Error('每次支持分享 1—9 张图片');
    const directory = context.filesDir + '/incoming'; if (!fs.accessSync(directory)) fs.mkdirSync(directory);
    for (const record of records) {
      if (!record.uri) { share.errors++; continue; }
      let input: fs.File | undefined;
      try {
        input = await fs.open(record.uri, fs.OpenMode.READ_ONLY);
        if (fs.statSync(input.fd).size > 30 * 1024 * 1024) throw new Error('图片过大');
        const path = directory + '/' + uuid() + '.image'; await fs.copyFile(input.fd, path); share.files.push(path);
      } catch (_) { share.errors++; } finally { if (input) await fs.close(input); }
    }
    const file = fs.openSync(directory + '/' + share.id + '.json', fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, JSON.stringify(share)); fs.fsyncSync(file.fd); } finally { fs.closeSync(file); }
    AppStorage.setOrCreate('incomingAt', Date.now());
  }
}
