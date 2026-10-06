import { util } from '@kit.ArkTS';
import { LocationLabelRepository } from '../data/repository/LocationLabelRepository';
import { LocationLabel } from '../model/LocationLabel';
import { LocationService } from './LocationService';
import { LocationRecord } from '../model/Location';
import { AppError, AppErrorCode } from '../common/AppError';

export class LocationLabelService {
  private repository: LocationLabelRepository;
  private locations: LocationService;

  constructor(repository: LocationLabelRepository, locations: LocationService) {
    this.repository = repository;
    this.locations = locations;
  }

  async list(): Promise<LocationLabel[]> { return this.repository.list(); }

  async create(locationId: string): Promise<LocationLabel> {
    await this.requireLocation(locationId);
    const label: LocationLabel = { token: util.generateRandomUUID(true), locationId: locationId };
    await this.repository.save(label);
    return label;
  }

  uri(label: LocationLabel): string {
    return 'itemnest://location/' + label.token;
  }

  async resolve(token: string): Promise<LocationRecord> {
    const label = (await this.list()).find((value: LocationLabel) => value.token === token);
    if (label === undefined) { throw new AppError(AppErrorCode.NOT_FOUND, '标签未关联到本机的位置，或关联已解除'); }
    return this.requireLocation(label.locationId);
  }

  async bind(token: string, locationId: string): Promise<void> {
    if (!/^[a-fA-F0-9-]{32,36}$/.test(token)) { throw new AppError(AppErrorCode.VALIDATION, '标签格式无效'); }
    await this.requireLocation(locationId);
    await this.repository.save({ token: token, locationId: locationId });
  }

  async remove(token: string): Promise<void> {
    await this.repository.remove(token);
  }

  private async requireLocation(id: string): Promise<LocationRecord> {
    const result = await this.locations.list();
    if (!result.ok) { throw result.getError(); }
    const location = result.getData().find((entry: LocationRecord) => entry.id === id && entry.active);
    if (location === undefined) { throw new AppError(AppErrorCode.NOT_FOUND, '位置已删除或停用，请重新绑定标签'); }
    return location;
  }

}
