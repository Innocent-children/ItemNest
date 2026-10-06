import { common, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { fileUri } from '@kit.CoreFileKit';
import { ExternalRequest } from '../model/SystemFeatures';

export class ShareService {
  async share(context: common.UIAbilityContext, title: string, text: string, photoPath?: string): Promise<void> {
    const data = new systemShare.SharedData({ utd: 'general.plain-text', title: title, content: text });
    if (photoPath !== undefined && photoPath.length > 0) {
      data.addRecord({ utd: 'general.image', uri: fileUri.getUriFromPath(photoPath), title: title });
    }
    await new systemShare.ShareController(data).show(context, { previewMode: systemShare.SharePreviewMode.DETAIL });
  }

  async receive(want: Want): Promise<ExternalRequest> {
    const data = await systemShare.getSharedData(want);
    const records = data.getRecords();
    const photo = records.find((record: systemShare.SharedRecord) =>
      /image|jpeg|png|webp|heic/.test(record.utd) && record.uri !== undefined);
    const text = records.filter((record: systemShare.SharedRecord) => /text/.test(record.utd))
      .map((record: systemShare.SharedRecord) => record.content ?? '').join('\n').slice(0, 10000);
    if (photo === undefined && text.length === 0) { throw new Error('没有可录入的照片或文字'); }
    return { action: 'add', photoUri: photo?.uri, text: text };
  }
}
