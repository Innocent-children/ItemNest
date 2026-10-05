import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result, success } from '../common/Result';
import { AssetRepositoryPort } from '../data/repository/AssetRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { Item, ItemSummary, PhotoState } from '../model/Item';
import { AssetSource, ItemAsset } from '../model/ItemAsset';
import { LocalAssetStorage } from './LocalAssetStorage';

export class PhotoService {
  private readonly assets: AssetRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly storage: LocalAssetStorage;
  private readonly clock: () => number;

  constructor(assets: AssetRepositoryPort, items: ItemRepositoryPort, storage: LocalAssetStorage, clock: () => number = () => Date.now()) {
    this.assets = assets;
    this.items = items;
    this.storage = storage;
    this.clock = clock;
  }

  async attach(item: Item, sourceUri: string, source: AssetSource): Promise<Result<Item>> {
    const assetId = this.createAssetId();
    const copiedResult = await this.storage.copyFromPickerUri(sourceUri, assetId);
    if (!copiedResult.ok) {
      return failure<Item>(copiedResult.getError());
    }
    const asset: ItemAsset = {
      id: assetId,
      itemId: item.id,
      localPath: copiedResult.getData(),
      source: source,
      createdAt: this.clock()
    };
    const createAssetResult = await this.assets.create(asset);
    if (!createAssetResult.ok) {
      await this.storage.remove(asset.localPath);
      return failure<Item>(createAssetResult.getError());
    }
    const updatedItem: Item = {
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      locationPath: item.locationPath,
      category: item.category,
      expirationDate: item.expirationDate,
      reminderDays: item.reminderDays,
      notes: item.notes,
      barcode: item.barcode,
      photoState: PhotoState.LOCAL,
      photoLocalId: asset.id,
      createdAt: item.createdAt,
      updatedAt: this.clock()
    };
    const updateResult = await this.items.update(updatedItem);
    if (!updateResult.ok) {
      await this.assets.deleteById(asset.id);
      await this.storage.remove(asset.localPath);
      return failure<Item>(updateResult.getError());
    }
    await this.removePreviousAsset(item.photoLocalId);
    return success<Item>(updatedItem);
  }

  async getLocalPath(item: Item): Promise<Result<string | undefined>> {
    if (item.photoLocalId === undefined || item.photoState !== PhotoState.LOCAL) {
      return success<string | undefined>(undefined);
    }
    const assetResult = await this.assets.getById(item.photoLocalId);
    if (!assetResult.ok) {
      return failure<string | undefined>(assetResult.getError());
    }
    return success<string | undefined>(assetResult.getData()?.localPath);
  }

  /**
   * 首页多个分区可能包含同一照片，一次加载中按资产标识合并查询。
   * 照片读取失败时保留物品本身，由界面展示占位图。
   */
  async loadThumbnails(items: ItemSummary[]): Promise<void> {
    const paths = new Map<string, Promise<string | undefined>>();
    await Promise.all(items.map(async (item: ItemSummary) => {
      const assetId = item.photoLocalId;
      if (assetId === undefined) {
        return;
      }
      let request = paths.get(assetId);
      if (request === undefined) {
        request = this.assets.getById(assetId).then((result: Result<ItemAsset | undefined>) =>
          result.ok ? result.getData()?.localPath : undefined).catch(() => undefined);
        paths.set(assetId, request);
      }
      item.photoPath = await request;
    }));
  }

  async remove(item: Item): Promise<Result<Item>> {
    if (item.photoLocalId === undefined || item.photoState !== PhotoState.LOCAL) {
      return success<Item>(item);
    }
    const assetResult = await this.assets.getById(item.photoLocalId);
    if (!assetResult.ok) {
      return failure<Item>(assetResult.getError());
    }
    const updatedItem: Item = {
      id: item.id, name: item.name, quantity: item.quantity, unit: item.unit,
      locationPath: item.locationPath, category: item.category, expirationDate: item.expirationDate,
      reminderDays: item.reminderDays, notes: item.notes, barcode: item.barcode, photoState: PhotoState.NONE,
      photoLocalId: undefined, createdAt: item.createdAt, updatedAt: this.clock()
    };
    const updateResult = await this.items.update(updatedItem);
    if (!updateResult.ok) {
      return failure<Item>(updateResult.getError());
    }
    const asset = assetResult.getData();
    if (asset !== undefined) {
      const removedResult = await this.storage.remove(asset.localPath);
      if (removedResult.ok) {
        await this.assets.deleteById(asset.id);
      }
    }
    return success<Item>(updatedItem);
  }

  async cleanupAfterItemDeleted(item: Item, knownLocalPath?: string): Promise<Result<void>> {
    if (knownLocalPath !== undefined) {
      return this.storage.remove(knownLocalPath);
    }
    if (item.photoLocalId === undefined) {
      return success<void>(undefined);
    }
    const assetResult = await this.assets.getById(item.photoLocalId);
    if (!assetResult.ok) {
      return failure<void>(assetResult.getError());
    }
    const asset = assetResult.getData();
    if (asset === undefined) {
      return success<void>(undefined);
    }
    const removedResult = await this.storage.remove(asset.localPath);
    if (!removedResult.ok) {
      return failure<void>(removedResult.getError());
    }
    return this.assets.deleteById(asset.id);
  }

  private async removePreviousAsset(previousAssetId?: string): Promise<void> {
    if (previousAssetId === undefined) {
      return;
    }
    const assetResult = await this.assets.getById(previousAssetId);
    if (!assetResult.ok || assetResult.getData() === undefined) {
      return;
    }
    const previousAsset = assetResult.getData() as ItemAsset;
    const removedResult = await this.storage.remove(previousAsset.localPath);
    if (removedResult.ok) {
      await this.assets.deleteById(previousAsset.id);
    }
  }

  private createAssetId(): string {
    const randomPart = Math.floor(Math.random() * 1000000000).toString(36);
    return `asset-${this.clock().toString(36)}-${randomPart}`;
  }
}
