import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode } from '../../common/AppError';
import { AssetSource, ItemAsset } from '../../model/ItemAsset';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ASSET_TABLE } from '../rdb/AssetSchema';

export class AssetDao {
  private readonly database: RdbDatabase;

  constructor(database: RdbDatabase) {
    this.database = database;
  }

  async create(asset: ItemAsset): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const rowId = await store.insert(ASSET_TABLE, this.toValues(asset));
        if (rowId < 0) {
          throw new AppError(AppErrorCode.DATABASE_WRITE, '保存图片记录失败，请重试');
        }
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '保存图片记录失败，请重试');
    }
  }

  async findById(assetId: string): Promise<ItemAsset | undefined> {
    const predicates = new relationalStore.RdbPredicates(ASSET_TABLE);
    predicates.equalTo('id', assetId);
    const assets = await this.query(predicates);
    return assets.length === 0 ? undefined : assets[0];
  }

  async findLatestByItemId(itemId: string): Promise<ItemAsset | undefined> {
    const predicates = new relationalStore.RdbPredicates(ASSET_TABLE);
    predicates.equalTo('item_id', itemId);
    predicates.orderByDesc('created_at');
    predicates.limitAs(1);
    const assets = await this.query(predicates);
    return assets.length === 0 ? undefined : assets[0];
  }

  async deleteById(assetId: string): Promise<void> {
    try {
      await this.database.transaction(async (store: relationalStore.RdbStore): Promise<void> => {
        const predicates = new relationalStore.RdbPredicates(ASSET_TABLE);
        predicates.equalTo('id', assetId);
        await store.delete(predicates);
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_WRITE, '清理图片记录失败，请重试');
    }
  }

  private async query(predicates: relationalStore.RdbPredicates): Promise<ItemAsset[]> {
    try {
      const store = await this.database.requireStore();
      const resultSet = await store.query(predicates);
      const assets: ItemAsset[] = [];
      try {
        while (resultSet.goToNextRow()) {
          assets.push(this.mapAsset(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return assets;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.DATABASE_READ, '读取图片记录失败，请重试');
    }
  }

  private mapAsset(resultSet: relationalStore.ResultSet): ItemAsset {
    return {
      id: this.readString(resultSet, 'id') ?? '',
      itemId: this.readString(resultSet, 'item_id') ?? '',
      localPath: this.readString(resultSet, 'local_path') ?? '',
      source: (this.readString(resultSet, 'source') ?? AssetSource.PHOTO_PICKER) as AssetSource,
      createdAt: this.readLong(resultSet, 'created_at') ?? 0
    };
  }

  private toValues(asset: ItemAsset): relationalStore.ValuesBucket {
    return {
      id: asset.id,
      item_id: asset.itemId,
      local_path: asset.localPath,
      source: asset.source,
      created_at: asset.createdAt
    };
  }

  private readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
  }

  private readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    const index = resultSet.getColumnIndex(column);
    return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
  }
}
