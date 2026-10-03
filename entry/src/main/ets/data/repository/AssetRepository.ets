import { AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { ItemAsset } from '../../model/ItemAsset';
import { AssetDao } from '../dao/AssetDao';

export interface AssetRepositoryPort {
  create(asset: ItemAsset): Promise<Result<ItemAsset>>;
  getById(assetId: string): Promise<Result<ItemAsset | undefined>>;
  getLatestByItemId(itemId: string): Promise<Result<ItemAsset | undefined>>;
  deleteById(assetId: string): Promise<Result<void>>;
}

export class AssetRepository implements AssetRepositoryPort {
  private readonly dao: AssetDao;

  constructor(dao: AssetDao) {
    this.dao = dao;
  }

  async create(asset: ItemAsset): Promise<Result<ItemAsset>> {
    try {
      await this.dao.create(asset);
      return success<ItemAsset>(asset);
    } catch (error) {
      return failure<ItemAsset>(toAppError(error, AppErrorCode.DATABASE_WRITE, '保存图片记录失败，请重试'));
    }
  }

  async getById(assetId: string): Promise<Result<ItemAsset | undefined>> {
    try {
      return success<ItemAsset | undefined>(await this.dao.findById(assetId));
    } catch (error) {
      return failure<ItemAsset | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取图片记录失败，请重试'));
    }
  }

  async listAll(): Promise<Result<ItemAsset[]>> {
    try {
      return success(await this.dao.findAll());
    } catch (error) {
      return failure<ItemAsset[]>(toAppError(error, AppErrorCode.DATABASE_READ, '读取图片记录失败，请重试'));
    }
  }

  async getLatestByItemId(itemId: string): Promise<Result<ItemAsset | undefined>> {
    try {
      return success<ItemAsset | undefined>(await this.dao.findLatestByItemId(itemId));
    } catch (error) {
      return failure<ItemAsset | undefined>(toAppError(error, AppErrorCode.DATABASE_READ, '读取图片记录失败，请重试'));
    }
  }

  async deleteById(assetId: string): Promise<Result<void>> {
    try {
      await this.dao.deleteById(assetId);
      return success<void>(undefined);
    } catch (error) {
      return failure<void>(toAppError(error, AppErrorCode.DATABASE_WRITE, '清理图片记录失败，请重试'));
    }
  }
}
