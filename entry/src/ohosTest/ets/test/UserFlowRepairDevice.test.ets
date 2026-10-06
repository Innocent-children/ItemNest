import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { RdbDatabase } from '../../../main/ets/data/rdb/RdbDatabase';
import { ItemDao } from '../../../main/ets/data/dao/ItemDao';
import { BatchDao } from '../../../main/ets/data/dao/BatchDao';
import { ItemRepository } from '../../../main/ets/data/repository/ItemRepository';
import { BatchRepository } from '../../../main/ets/data/repository/BatchRepository';
import { TraceEventRepository } from '../../../main/ets/data/repository/TraceEventRepository';
import { ItemValidator } from '../../../main/ets/common/ItemValidator';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { ItemUpdateService } from '../../../main/ets/service/ItemUpdateService';
import { LendingService } from '../../../main/ets/service/LendingService';
import { BatchService } from '../../../main/ets/service/BatchService';
import { LocalAssetStorage } from '../../../main/ets/service/LocalAssetStorage';

export default function userFlowRepairDeviceTest() {
  describe('User flow repair on device', () => {
    it('图片通过 URI 读取并复制到私有目录，失败时不遗留文件', 0, async () => {
      const ctx = (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
      const source = `${ctx.cacheDir}/ux-repair-image-source`;
      const file = await fileIo.open(source, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      await fileIo.write(file.fd, 'itemnest-photo-uri');
      await fileIo.close(file);
      const storage = new LocalAssetStorage(ctx);
      let destination = '';
      try {
        const result = await storage.copyFromPickerUri(fileUri.getUriFromPath(source), 'ux-repair-image-copy');
        expect(result.ok).assertTrue();
        destination = result.getData();
        expect(await fileIo.readText(destination)).assertEqual('itemnest-photo-uri');
        const failed = await storage.copyFromPickerUri(fileUri.getUriFromPath(`${source}-missing`), 'ux-repair-missing');
        expect(failed.ok).assertFalse();
        expect((await storage.listOwnedPaths()).getData().some((path: string) => path.endsWith('/ux-repair-missing'))).assertFalse();
      } finally {
        await fileIo.unlink(source);
        if (destination.length > 0) { await storage.remove(destination); }
      }
    });

    it('单批次修改原子保存，借出数量保护与指定位置消耗均生效', 0, async () => {
      const ctx = (await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()).context;
      const name = 'itemnest-ux-repair-isolated.db';
      try { await relationalStore.deleteRdbStore(ctx, name); } catch (_) {}
      const db = new RdbDatabase(ctx, name);
      const items = new ItemRepository(new ItemDao(db));
      const batches = new BatchRepository(new BatchDao(db));
      const update = new ItemUpdateService(items, new ItemValidator(), () => 2, batches);
      const lending = new LendingService(new TraceEventRepository(db), items);
      const inventory = new BatchService(batches, items);
      try {
        expect((await items.create({ id: 'ux-item', name: '纸巾', quantity: 3, unit: ItemUnit.PIECE,
          locationPath: '厨房', photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1 })).ok).assertTrue();
        const saved = await update.update('ux-item', { name: '纸巾', quantity: 4.1, unit: ItemUnit.PACK,
          locationPath: '客厅', expirationDate: '2027-01-01' });
        expect(saved.ok).assertTrue();
        const first = (await batches.listByItemId('ux-item')).getData()[0];
        expect(first.quantity).assertEqual(4.1);
        expect(first.unit).assertEqual(ItemUnit.PACK);
        expect(first.locationPath).assertEqual('客厅');
        expect(saved.getData().expirationDate).assertEqual('2027-01-01');
        expect((await lending.borrow('ux-item', 2, '测试借用人')).ok).assertTrue();
        const rejected = await update.update('ux-item', { name: '不应保存的名字', quantity: 1.1,
          unit: ItemUnit.PACK, locationPath: '不应保存的位置' });
        expect(rejected.ok).assertFalse();
        expect((await items.getById('ux-item')).getData()?.name).assertEqual('纸巾');
        expect((await batches.getById(first.id)).getData()?.quantity).assertEqual(4.1);
        const second = (await inventory.create({ itemId: 'ux-item', quantity: 2, unit: ItemUnit.PACK,
          locationPath: '办公室', expirationDate: '2027-02-01' })).getData();
        expect((await inventory.consume('ux-item', 1, second.id)).ok).assertTrue();
        expect((await batches.getById(first.id)).getData()?.quantity).assertEqual(4.1);
        expect((await batches.getById(second.id)).getData()?.quantity).assertEqual(1);
        expect((await items.getById('ux-item')).getData()?.quantity).assertEqual(5.1);
      } finally {
        const store = await db.requireStore();
        store.close();
        await relationalStore.deleteRdbStore(ctx, name);
      }
    });
  });
}
