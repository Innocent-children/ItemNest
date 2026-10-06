import { tag, nfcController } from '@kit.ConnectivityKit';
import { bundleManager, Want } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { ExternalRequestParser } from '../../navigation/ExternalRequestParser';

export class NfcLabelAdapter {
  private static active?: NfcLabelAdapter;

  static stopActive(): void { NfcLabelAdapter.active?.stop(); }

  private readonly element: bundleManager.ElementName = {
    bundleName: 'com.imotong.itemtrace', abilityName: 'EntryAbility', moduleName: 'entry'
  };
  private callback?: (error: BusinessError, info: tag.TagInfo) => void;
  private busy: boolean = false;

  available(): boolean {
    try { return nfcController.isNfcAvailable() && nfcController.isNfcOpen(); } catch (_) { return false; }
  }

  start(uriToWrite: string | undefined, onResult: (uri: string, error: string) => void): void {
    NfcLabelAdapter.stopActive();
    this.stop();
    if (!this.available()) { onResult('', '设备未开启 NFC 或不支持 NFC，请使用二维码'); return; }
    this.callback = (error: BusinessError, info: tag.TagInfo): void => {
      if (error) { onResult('', 'NFC 读取失败，请重新贴近标签'); return; }
      if (!this.busy) { this.exchange(info, uriToWrite, onResult); }
    };
    try {
      NfcLabelAdapter.active = this;
      tag.on('readerMode', this.element, [tag.NFC_A, tag.NFC_B, tag.NFC_F, tag.NFC_V], this.callback);
    } catch (_) { this.stop(); onResult('', '无法开始 NFC 读写，请检查 NFC 开关'); }
  }

  stop(): void {
    if (NfcLabelAdapter.active === this) { NfcLabelAdapter.active = undefined; }
    if (this.callback !== undefined) {
      try { tag.off('readerMode', this.element, this.callback); } catch (_) {}
      this.callback = undefined;
    }
  }

  async readWant(want: Want): Promise<string> {
    return this.read(tag.getTagInfo(want));
  }

  private async exchange(info: tag.TagInfo, uri: string | undefined, onResult: (uri: string, error: string) => void): Promise<void> {
    this.busy = true;
    try {
      if (uri !== undefined) {
        const ndef = tag.getNdef(info);
        ndef.connect();
        try {
          if (!ndef.isNdefWritable()) { throw new Error('readonly'); }
          await ndef.writeNdef(tag.ndef.createNdefMessage([
            tag.ndef.makeUriRecord(uri), tag.ndef.makeApplicationRecord('com.imotong.itemtrace')
          ]));
        } finally { ndef.resetConnection(); }
        this.stop();
        onResult(uri, '');
      } else {
        const result = await this.read(info);
        this.stop();
        onResult(result, '');
      }
    } catch (_) { onResult('', '标签读写失败，请使用可读写的 NDEF 标签并保持贴近'); }
    finally { this.busy = false; }
  }

  private async read(info: tag.TagInfo): Promise<string> {
    const ndef = tag.getNdef(info);
    ndef.connect();
    try {
      const message = await ndef.readNdef();
      for (const record of message.getNdefRecords()) {
        if (record.tnf === tag.TnfType.TNF_WELL_KNOWN && record.rtdType[0] === 0x55 && record.payload[0] === 0) {
          const uri = new util.TextDecoder().decodeToString(new Uint8Array(record.payload.slice(1)));
          if (ExternalRequestParser.parseUri(uri)?.action === 'location') { return uri; }
        }
      }
      throw new Error('not itemtrace label');
    } finally { ndef.resetConnection(); }
  }
}
