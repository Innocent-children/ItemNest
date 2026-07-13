import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { createLocationId, LocationDraft, LocationRecord } from '../model/Location';
import { LOCATION_PATH_MAX_LENGTH } from '../model/LocationPath';
import { BatchRepositoryPort } from '../data/repository/BatchRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { LocationRepositoryPort } from '../data/repository/LocationRepository';

export class LocationService {
  private readonly locations: LocationRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;
  private readonly batches?: BatchRepositoryPort;

  constructor(locations: LocationRepositoryPort, items: ItemRepositoryPort, clock: () => number = () => Date.now(),
    batches?: BatchRepositoryPort) {
    this.locations = locations;
    this.items = items;
    this.clock = clock;
    this.batches = batches;
  }

  async list(): Promise<Result<LocationRecord[]>> {
    return this.locations.listAll();
  }

  async create(draft: LocationDraft): Promise<Result<LocationRecord>> {
    const name = draft.name?.trim() ?? '';
    if (name.length === 0 || name.length > 80) {
      return failure<LocationRecord>(new AppError(AppErrorCode.VALIDATION, '位置名称需为 1 至 80 个字符'));
    }
    if (name.includes('/')) {
      return failure<LocationRecord>(new AppError(AppErrorCode.VALIDATION, '位置名称不能包含路径分隔符 /'));
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
    if (path.length > LOCATION_PATH_MAX_LENGTH) {
      return failure<LocationRecord>(new AppError(AppErrorCode.VALIDATION, '位置路径不能超过 200 个字符'));
    }
    const locationsResult = await this.locations.listAll();
    if (!locationsResult.ok) {
      return failure<LocationRecord>(locationsResult.getError());
    }
    if (locationsResult.getData().some((location: LocationRecord) => location.path === path)) {
      return failure<LocationRecord>(new AppError(AppErrorCode.VALIDATION, '同一路径下已存在该位置'));
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
    const locationsResult = await this.locations.listAll();
    if (!locationsResult.ok) {
      return failure<void>(locationsResult.getError());
    }
    const locations = locationsResult.getData();
    for (let index = 0; index < locations.length; index++) {
      const candidate = locations[index];
      if (candidate.id !== location.id && candidate.active && this.isSameOrDescendant(candidate.path, location.path)) {
        return failure<void>(new AppError(AppErrorCode.VALIDATION, '该位置仍有启用的子位置，请先停用子位置'));
      }
    }
    const itemResult = await this.items.listAll();
    if (!itemResult.ok) {
      return failure<void>(itemResult.getError());
    }
    const items = itemResult.getData();
    for (let index = 0; index < items.length; index++) {
      const itemPath = items[index].locationPath;
      if (itemPath !== undefined && this.isSameOrDescendant(itemPath, location.path)) {
        return failure<void>(new AppError(AppErrorCode.VALIDATION, '该位置仍被物品引用，请先迁移物品位置'));
      }
    }
    if (this.batches !== undefined) {
      const batchResult = await this.batches.listAll();
      if (!batchResult.ok) {
        return failure<void>(batchResult.getError());
      }
      const batches = batchResult.getData();
      for (let index = 0; index < batches.length; index++) {
        const batchPath = batches[index].locationPath;
        if (batchPath !== undefined && this.isSameOrDescendant(batchPath, location.path)) {
          return failure<void>(new AppError(AppErrorCode.VALIDATION, '该位置仍被批次引用，请先迁移批次位置'));
        }
      }
    }
    return this.locations.setActive(locationId, false, this.clock());
  }

  async activate(locationId: string): Promise<Result<void>> {
    const locationResult = await this.locations.getById(locationId);
    if (!locationResult.ok) {
      return failure<void>(locationResult.getError());
    }
    const location = locationResult.getData();
    if (location === undefined) {
      return failure<void>(new AppError(AppErrorCode.NOT_FOUND, '位置不存在或已删除'));
    }
    if (location.parentId !== undefined) {
      const parentResult = await this.locations.getById(location.parentId);
      if (!parentResult.ok) {
        return failure<void>(parentResult.getError());
      }
      if (parentResult.getData() === undefined || !parentResult.getData()?.active) {
        return failure<void>(new AppError(AppErrorCode.VALIDATION, '请先启用父级位置'));
      }
    }
    return this.locations.setActive(locationId, true, this.clock());
  }

  private isSameOrDescendant(path: string, rootPath: string): boolean {
    return path === rootPath || path.startsWith(`${rootPath} / `);
  }
}
