import { describe, it, expect } from '@ohos/hypium';
import { Result, success } from '../../../main/ets/common/Result';
import { BatchRepositoryPort } from '../../../main/ets/data/repository/BatchRepository';
import { LocationRepositoryPort } from '../../../main/ets/data/repository/LocationRepository';
import { Batch } from '../../../main/ets/model/Batch';
import { ItemUnit, PhotoState } from '../../../main/ets/model/Item';
import { LocationRecord } from '../../../main/ets/model/Location';
import { LocationService } from '../../../main/ets/service/LocationService';
import { FakeItemRepository } from './FakeItemRepository';

class FakeLocationRepository implements LocationRepositoryPort {
  locations: LocationRecord[] = [];

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
