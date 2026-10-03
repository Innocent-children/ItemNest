import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { AssetRepository } from '../data/repository/AssetRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { LocalAssetStorage } from './LocalAssetStorage';

export class PhotoMaintenanceService {
  private readonly assets: AssetRepository;
  private readonly items: ItemRepositoryPort;
  private readonly storage: LocalAssetStorage;

  constructor(assets: AssetRepository, items: ItemRepositoryPort, storage: LocalAssetStorage) {
    this.assets = assets;
    this.items = items;
    this.storage = storage;
  }

  async cleanupOrphans(): Promise<Result<number>> {
    const itemResult = await this.items.listAll();
    const assetResult = await this.assets.listAll();
    const fileResult = await this.storage.listOwnedPaths();
    if (!itemResult.ok || !assetResult.ok || !fileResult.ok) {
      return failure<number>(new AppError(AppErrorCode.ASSET_STORAGE, '图片清理暂不可用'));
    }
    const activeIds = new Set<string>();
    for (const item of itemResult.getData()) {
      if (item.photoLocalId !== undefined) {
        activeIds.add(item.photoLocalId);
      }
    }
    const activePaths = new Set<string>();
    const removedPaths = new Set<string>();
    let cleaned = 0;
    for (const asset of assetResult.getData()) {
      if (activeIds.has(asset.id)) {
        activePaths.add(asset.localPath);
        continue;
      }
      const removed = await this.storage.remove(asset.localPath);
      if (removed.ok) {
        removedPaths.add(asset.localPath);
        const deleted = await this.assets.deleteById(asset.id);
        if (deleted.ok) {
          cleaned++;
        }
      }
    }
    for (const path of fileResult.getData()) {
      if (!activePaths.has(path) && !removedPaths.has(path)) {
        const removed = await this.storage.remove(path);
        if (removed.ok) {
          cleaned++;
        }
      }
    }
    return success(cleaned);
  }
}
