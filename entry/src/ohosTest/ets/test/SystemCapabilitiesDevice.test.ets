import { relationalStore } from '@kit.ArkData';
import { RdbDatabase, migrateToLatest } from '../../../main/ets/data/rdb/RdbDatabase';
import { ItemDao } from '../../../main/ets/data/dao/ItemDao';
import { ItemRepository } from '../../../main/ets/data/repository/ItemRepository';
import { LocationRepository } from '../../../main/ets/data/repository/LocationRepository';
import { LocationLabelRepository } from '../../../main/ets/data/repository/LocationLabelRepository';
import { LocationService } from '../../../main/ets/service/LocationService';
import { LocationLabelService } from '../../../main/ets/service/LocationLabelService';
import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo } from '@kit.CoreFileKit';
import { textSearchImage } from '@kit.CoreVisionKit';
import { tag, nfcController } from '@kit.ConnectivityKit';
import { TextRecognitionAdapter } from '../../../main/ets/service/adapter/TextRecognitionAdapter';
import { CaptureDraftService } from '../../../main/ets/service/CaptureDraftService';
import { ExternalRequestParser } from '../../../main/ets/navigation/ExternalRequestParser';

async function writeFixture(name: string): Promise<string> {
  const context = (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
  const bytes = await context.createModuleContext('entry_test').resourceManager.getRawFileContent(name);
  const path = context.cacheDir + '/' + name;
  const file = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
  try { await fileIo.write(file.fd, bytes.buffer); } finally { await fileIo.close(file); }
  return path;
}

export default function systemCapabilitiesDeviceTest() {
  describe('SystemCapabilitiesDevice', () => {
    it('label_survives_location_rename_and_can_be_revoked', 0, async () => {
      const context = (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
      const name = 'itemtrace-system-label-test.db';
      const database = new RdbDatabase(context, name);
      try {
        const locations = new LocationService(new LocationRepository(database), new ItemRepository(new ItemDao(database)));
        const labels = new LocationLabelService(new LocationLabelRepository(database), locations);
        const created = await locations.create({ name: '测试收纳位置' });
        expect(created.ok).assertTrue();
        const label = await labels.create(created.getData().id);
        expect((await locations.rename(created.getData().id, '已改名的测试位置')).ok).assertTrue();
        expect((await labels.resolve(label.token)).path).assertEqual('已改名的测试位置');
        const other = await locations.create({ name: '第二个测试位置' });
        await labels.bind(label.token, other.getData().id);
        expect((await labels.resolve(label.token)).id).assertEqual(other.getData().id);
        await labels.remove(label.token);
        let rejected = false;
        try { await labels.resolve(label.token); } catch (_) { rejected = true; }
        expect(rejected).assertTrue();
      } finally {
        await database.close();
        await relationalStore.deleteRdbStore(context, name);
      }
    });
    it('database_upgrade_adds_labels_without_replacing_locations', 0, async () => {
      const context = (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
      const name = 'itemtrace-label-upgrade-test.db';
      const store = await relationalStore.getRdbStore(context, { name: name, securityLevel: relationalStore.SecurityLevel.S3 });
      try {
        await migrateToLatest(store);
        await store.executeSql('DROP TABLE location_label');
        await store.insert('managed_location', { id: 'upgrade-location', name: '原位置', path: '原位置', active: 1, created_at: 1, updated_at: 1 });
        store.version = 12;
        await migrateToLatest(store);
        expect(store.version).assertEqual(13);
        await store.insert('location_label', { token: '12345678123412341234123456789012', location_id: 'upgrade-location' });
        const rows = await store.querySql('SELECT name FROM managed_location WHERE id = ?', ['upgrade-location']);
        try { expect(rows.rowCount).assertEqual(1); } finally { rows.close(); }
      } finally {
        store.close();
        await relationalStore.deleteRdbStore(context, name);
      }
    });
    it('ocr_extracts_labeled_expiry_on_device', 0, async () => {
      const path = await writeFixture('itemtrace_ocr_fixture.png');
      try {
        const recognized = await new TextRecognitionAdapter().recognize(path);
        expect(recognized.ok).assertTrue();
        if (!recognized.ok) { return; }
        const draft = new CaptureDraftService().parse(recognized.getData());
        expect(draft.name.includes('牛奶')).assertTrue();
        expect(draft.productionDate).assertEqual('2026-10-06');
        expect(draft.expirationDate).assertEqual('2026-10-13');
      } finally { await fileIo.unlink(path); }
    });
    it('photo_index_search_and_delete_on_device', 0, async () => {
      const path = await writeFixture('itemtrace_photo_fixture.png');
      const scope = 'ItemTraceDeviceTest';
      let initialized = false;
      try {
        initialized = await textSearchImage.init();
        expect(initialized).assertTrue();
        if (!initialized) { return; }
        expect(await textSearchImage.insertImage(path, scope)).assertTrue();
        const matches = await textSearchImage.search('蓝色的袋子', scope, 5);
        expect(matches.some(match => match.imagePath === path)).assertTrue();
        expect(await textSearchImage.deleteImage(path, scope)).assertTrue();
        const after = await textSearchImage.search('蓝色的袋子', scope, 5);
        expect(after.some(match => match.imagePath === path)).assertFalse();
      } finally {
        if (initialized) {
          try { await textSearchImage.deleteImage(path, scope); } catch (_) {}
          await textSearchImage.release();
        }
        await fileIo.unlink(path);
      }
    });
    it('nfc_ndef_label_contains_only_location_token', 0, () => {
      expect(nfcController.isNfcAvailable()).assertTrue();
      const uri = 'itemtrace://location/12345678123412341234123456789012';
      const record = tag.ndef.makeUriRecord(uri);
      const message = tag.ndef.createNdefMessage([record, tag.ndef.makeApplicationRecord('com.imotong.itemtrace')]);
      expect(message.getNdefRecords().length).assertEqual(2);
      expect(ExternalRequestParser.parseUri(uri)?.locationId).assertEqual('12345678123412341234123456789012');
    });
  });
}
