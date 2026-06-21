import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { createLocationId, LocationDraft, LocationRecord } from '../model/Location';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { LocationRepository } from '../data/repository/LocationRepository';

export class LocationService {
  private readonly locations: LocationRepository;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;

  constructor(locations: LocationRepository, items: ItemRepositoryPort, clock: () => number = () => Date.now()) {
    this.locations = locations;
    this.items = items;
    this.clock = clock;
  }

  async list(): Promise<Result<LocationRecord[]>> {
    return this.locations.listAll();
  }

  async create(draft: LocationDraft): Promise<Result<LocationRecord>> {
    const name = draft.name?.trim() ?? '';
    if (name.length === 0 || name.length > 80) {
      return failure<LocationRecord>(new AppError(AppErrorCode.VALIDATION, '位置名称需为 1 至 80 个字符'));
    }
    let path = name;
    if (draft.parentId !== undefined && draft.parentId.length > 0) {
      const parentResult = await this.locations.getById(draft.parentId);
      if (!parentResult.ok) {
        return failure<LocationRecord>(parentResult.getError());
      }
      const parent = parentResult.getData();
      if (parent === undefined || !parent.active) {
        return failure<LocationRecord>(new AppError(AppErrorCode.NOT_FOUND, '父级位置不存在或已停用'));
      }
      path = `${parent.path} / ${name}`;
    }
    const now = this.clock();
    return this.locations.create({
      id: createLocationId(this.clock),
      name: name,
      parentId: draft.parentId,
      path: path,
      active: true,
      createdAt: now,
      updatedAt: now
    });
  }

  async deactivate(locationId: string): Promise<Result<void>> {
    const locationResult = await this.locations.getById(locationId);
    if (!locationResult.ok) {
      return failure<void>(locationResult.getError());
    }
    const location = locationResult.getData();
    if (location === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '位置不存在或已删除'));
    }
    const itemResult = await this.items.listAll();
    if (!itemResult.ok) {
      return failure<void>(itemResult.getError());
    }
    const items = itemResult.getData();
    for (let index = 0; index < items.length; index++) {
      if (items[index].locationPath === location.path) {
        return failure<void>(new AppError(AppErrorCode.VALIDATION, '该位置仍被物品引用，请先迁移物品位置'));
      }
    }
    return this.locations.setActive(locationId, false, this.clock());
  }

  async activate(locationId: string): Promise<Result<void>> {
    return this.locations.setActive(locationId, true, this.clock());
  }
}
