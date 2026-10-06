import { createLocationLabelSchema } from './LocationLabelSchema';
import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { addItemBarcode, createItemSchema, DATABASE_NAME, DATABASE_VERSION } from './ItemSchema';
import { addReminderMetadata, createReminderSchema } from './ReminderSchema';
import { createAssetSchema } from './AssetSchema';
import { createBatchSchema } from './BatchSchema';
import { createStockThresholdSchema } from './StockThresholdSchema';
import { createTraceEventSchema, migrateLendingRelations } from './TraceEventSchema';
import { createLocationSchema } from './LocationSchema';
import { createCategorySchema } from './CategorySchema';
import { createSearchHistorySchema } from './SearchHistorySchema';
import { createInventoryIntegritySchema, updateInventoryIntegritySchema } from './InventoryIntegritySchema';

export async function migrateToLatest(store: relationalStore.RdbStore): Promise<void> {
  const currentVersion = store.version;
  if (currentVersion > DATABASE_VERSION) {
    throw new AppError(AppErrorCode.DATABASE_INIT, '数据库版本不受当前应用支持');
  }
  if (currentVersion === DATABASE_VERSION) {
    return;
  }

  let transaction: relationalStore.Transaction | undefined = undefined;
  try {
    transaction = await store.createTransaction();
    if (currentVersion < 1) {
      await createItemSchema(transaction);
    }
    if (currentVersion < 2) {
      await createReminderSchema(transaction);
    }
    if (currentVersion < 3) {
      await createAssetSchema(transaction);
    }
    if (currentVersion < 4) {
      await createBatchSchema(transaction);
    }
    if (currentVersion < 5) {
      await createStockThresholdSchema(transaction);
    }
    if (currentVersion < 6) {
      await createTraceEventSchema(transaction);
    }
    if (currentVersion < 7) {
      await createLocationSchema(transaction);
    }
    if (currentVersion < 8) {
      await createCategorySchema(transaction);
    }
    if (currentVersion < 9) {
      await createSearchHistorySchema(transaction);
    }
    if (currentVersion < 10) {
      await createInventoryIntegritySchema(transaction);
    }
    if (currentVersion < 11) {
      await addItemBarcode(transaction);
    }
    if (currentVersion < 12) {
      await addReminderMetadata(transaction);
      await migrateLendingRelations(transaction);
      await updateInventoryIntegritySchema(transaction);
    }
    if (currentVersion < 13) { await createLocationLabelSchema(transaction); }
    await transaction.execute(`PRAGMA user_version = ${DATABASE_VERSION}`);
    await transaction.commit();
  } catch (error) {
    if (transaction !== undefined) {
      try {
        await transaction.rollback();
      } catch (_) {
        // 保留迁移失败结果，页面不会继续读取或写入。
      }
    }
    throw toAppError(error as Error, AppErrorCode.DATABASE_INIT, '数据库初始化失败，请重试');
  }
}

export class RdbDatabase {
  private readonly context: Context;
  private readonly databaseName: string;
  private store?: relationalStore.RdbStore;
  private initializing?: Promise<Result<relationalStore.RdbStore>>;
  private static readonly writeQueues: Map<string, Promise<void>> = new Map<string, Promise<void>>();

  constructor(context: Context, databaseName: string = DATABASE_NAME) {
    this.context = context;
    this.databaseName = databaseName;
  }

  async getStore(): Promise<Result<relationalStore.RdbStore>> {
    if (this.store !== undefined) {
      return success(this.store);
    }
    if (this.initializing === undefined) {
      this.initializing = this.openAndInitialize();
    }
    const result = await this.initializing;
    if (!result.ok) {
      // 初始化失败后清除缓存，允许“重新加载”再次尝试打开数据库。
      this.initializing = undefined;
    }
    return result;
  }

  async requireStore(): Promise<relationalStore.RdbStore> {
    const result = await this.getStore();
    if (!result.ok) {
      throw result.getError();
    }
    return result.getData();
  }

  async transaction<T>(operation: (store: relationalStore.Transaction) => Promise<T>): Promise<T> {
    const previous = RdbDatabase.writeQueues.get(this.databaseName) ?? Promise.resolve();
    let release: () => void = () => {};
    RdbDatabase.writeQueues.set(this.databaseName, new Promise<void>((resolve: () => void) => {
      release = resolve;
    }));
    await previous;
    try {
      return await this.runTransaction(operation);
    } finally {
      release();
    }
  }

  private async runTransaction<T>(operation: (store: relationalStore.Transaction) => Promise<T>): Promise<T> {
    const store = await this.requireStore();
    let transaction: relationalStore.Transaction | undefined = undefined;
    try {
      transaction = await store.createTransaction();
      const value = await operation(transaction);
      await transaction.commit();
      return value;
    } catch (error) {
      if (transaction !== undefined) {
        try {
          await transaction.rollback();
        } catch (_) {
          // 回滚失败不覆盖原始领域错误。
        }
      }
      throw toAppError(error as Error, AppErrorCode.DATABASE_WRITE, '数据库写入失败，请重试');
    }
  }

  close(): void {
    if (this.store !== undefined) {
      try {
        this.store.close();
      } catch (_) {
      }
      this.store = undefined;
      this.initializing = undefined;
    }
  }

  private async openAndInitialize(): Promise<Result<relationalStore.RdbStore>> {
    let openedStore: relationalStore.RdbStore | undefined = undefined;
    try {
      const config: relationalStore.StoreConfig = {
        name: this.databaseName,
        securityLevel: relationalStore.SecurityLevel.S3
      };
      openedStore = await relationalStore.getRdbStore(this.context, config);
      await migrateToLatest(openedStore);
      this.store = openedStore;
      return success(openedStore);
    } catch (error) {
      if (openedStore !== undefined) {
        try {
          openedStore.close();
        } catch (_) {
        }
      }
      return failure<relationalStore.RdbStore>(toAppError(error, AppErrorCode.DATABASE_INIT, '数据库初始化失败，请重试'));
    }
  }

}
