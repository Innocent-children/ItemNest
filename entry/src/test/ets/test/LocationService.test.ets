import { describe, it, expect } from '@ohos/hypium';
import { failure, Result, success } from '../../../main/ets/common/Result';
import { BatchRepositoryPort } from '../../../main/ets/data/repository/BatchRepository';
import { LocationRepositoryPort } from '../../../main/ets/data/repository/LocationRepository';
import { Batch } from '../../../main/ets/model/Batch';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { LocationRecord, LocationRenamePlan } from '../../../main/ets/model/Location';
import { LocationService } from '../../../main/ets/service/LocationService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeLocationRepository implements LocationRepositoryPort {
  locations: LocationRecord[] = [];

  paths: string[] = [];

  async renameAtomic(decide: (locations: LocationRecord[], paths: string[]) => Result<LocationRenamePlan>): Promise<Result<void>> {
    const result = decide(this.locations, this.paths);
    if (!result.ok) { return failure<void>(result.getError()); }
    const plan = result.getData();
    this.locations = this.locations.map((location: LocationRecord) =>
      plan.locations.find((updated: LocationRecord) => updated.id === location.id) ?? location);
    this.paths = this.paths.map((path: string) => path === plan.oldPath || path.startsWith(plan.oldPath + ' / ') ?
      plan.newPath + path.substring(plan.oldPath.length) : path);
    return success<void>(undefined);
  }

  async create(location: LocationRecord): Promise<Result<LocationRecord>> {
    this.locations.push(location);
    return success(location);
  }

  async listAll(): Promise<Result<LocationRecord[]>> {
    return success(this.locations.slice());
  }

  async getById(locationId: string): Promise<Result<LocationRecord | undefined>> {
    return success(this.locations.find((location: LocationRecord) => location.id === locationId));
  }

  async setActive(locationId: string, active: boolean, updatedAt: number): Promise<Result<void>> {
    const location = this.locations.find((current: LocationRecord) => current.id === locationId);
    if (location !== undefined) {
      location.active = active;
      location.updatedAt = updatedAt;
    }
    return success<void>(undefined);
  }
}

class FakeBatchRepository implements BatchRepositoryPort {
  batches: Batch[] = [];

  async create(batch: Batch): Promise<Result<Batch>> {
    this.batches.push(batch);
    return success(batch);
  }

  async getById(batchId: string): Promise<Result<Batch | undefined>> {
    return success(this.batches.find((batch: Batch) => batch.id === batchId));
  }

  async listByItemId(itemId: string): Promise<Result<Batch[]>> {
    return success(this.batches.filter((batch: Batch) => batch.itemId === itemId));
  }

  async listAll(): Promise<Result<Batch[]>> {
    return success(this.batches.slice());
  }

  async update(batch: Batch): Promise<Result<Batch>> {
    return success(batch);
  }

  async deleteConfirmed(batchId: string): Promise<Result<void>> {
    return success<void>(undefined);
  }
}

function location(id: string, path: string, active: boolean, parentId?: string): LocationRecord {
  const parts = path.split(' / ');
  return {
    id: id,
    name: parts[parts.length - 1],
    parentId: parentId,
    path: path,
    active: active,
    createdAt: 1,
    updatedAt: 1
  };
}

export default function locationServiceTest() {
  describe('LocationService', () => {
    it('改名保留位置身份并同步子路径，相似前缀不受影响', 0, async () => {
      const locations = new FakeLocationRepository();
      locations.locations = [location('root', '家', true), location('child', '家 / 厨房', false, 'root'), location('other', '家人', true)];
      locations.paths = ['家', '家 / 厨房 / 冰箱', '家人 / 柜子'];
      const service = new LocationService(locations, new FakeItemRepository(), () => 20);
      expect((await service.rename('root', '住处')).ok).assertTrue();
      expect(locations.locations[1].path).assertEqual('住处 / 厨房');
      expect(locations.locations[1].parentId).assertEqual('root');
      expect(locations.locations[1].active).assertFalse();
      expect(locations.paths[1]).assertEqual('住处 / 厨房 / 冰箱');
      expect(locations.paths[2]).assertEqual('家人 / 柜子');
    });

    it('重复或过长的改名不会改变现有路径', 0, async () => {
      const locations = new FakeLocationRepository();
      locations.locations = [location('one', '家', true), location('two', '办公室', true)];
      const service = new LocationService(locations, new FakeItemRepository(), () => 20);
      expect((await service.rename('one', '办公室')).ok).assertFalse();
      locations.paths = ['家 / ' + '柜'.repeat(196)];
      expect((await service.rename('one', '新的住处')).ok).assertFalse();
      expect(locations.locations[0].path).assertEqual('家');
    });

    it('停用位置前检查启用子节点及物品和批次的子路径引用', 0, async () => {
      const locations = new FakeLocationRepository();
      const parent = location('parent', '家', true);
      const child = location('child', '家 / 厨房', true, 'parent');
      locations.locations.push(parent);
      locations.locations.push(child);
      const items = new FakeItemRepository();
      const batches = new FakeBatchRepository();
      const service = new LocationService(locations, items, () => 10, batches);

      expect((await service.deactivate('parent')).ok).assertFalse();
      child.active = false;
      items.items.push({
        id: 'item-1', name: '牛奶', quantity: 1, unit: ItemUnit.BOX,
        locationPath: '家 / 厨房 / 冰箱', photoState: PhotoState.NONE, createdAt: 1, updatedAt: 1
      });
      expect((await service.deactivate('parent')).ok).assertFalse();
      items.items = [];
      batches.batches.push({
        id: 'batch-1', itemId: 'item-1', quantity: 1, unit: ItemUnit.BOX,
        locationPath: '家 / 厨房', createdAt: 1, updatedAt: 1
      });
      expect((await service.deactivate('parent')).ok).assertFalse();
      batches.batches = [];
      expect((await service.deactivate('parent')).ok).assertTrue();
      expect(parent.active).assertFalse();
    });

    it('父级停用时不能启用子位置，且拒绝重复路径和分隔符', 0, async () => {
      const locations = new FakeLocationRepository();
      const parent = location('parent', '家', false);
      const child = location('child', '家 / 厨房', false, 'parent');
      locations.locations.push(parent);
      locations.locations.push(child);
      const service = new LocationService(locations, new FakeItemRepository(), () => 10, new FakeBatchRepository());

      expect((await service.activate('child')).ok).assertFalse();
      expect((await service.create({ name: '客厅/柜子' })).ok).assertFalse();
      expect((await service.create({ name: '家' })).ok).assertFalse();
      expect((await service.activate('parent')).ok).assertTrue();
      expect((await service.activate('child')).ok).assertTrue();
    });
  });
}
