import { Context } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { AppError, AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { createItemSchema, DATABASE_NAME, DATABASE_VERSION } from './ItemSchema';

export async function migrateToV1(store: relationalStore.RdbStore): Promise<void> {
  const currentVersion = store.version;
  if (currentVersion > DATABASE_VERSION) {
    throw new AppError(AppErrorCode.DATABASE_INIT, '数据库版本不受当前应用支持');
  }
  if (currentVersion === DATABASE_VERSION) {
    return;
  }

  let started = false;
  try {
    store.beginTransaction();
    started = true;
    await createItemSchema(store);
    store.version = DATABASE_VERSION;
    store.commit();
  } catch (error) {
    if (started) {
      try {
        store.rollBack();
      } catch (_) {
        // 保留迁移失败结果，页面不会继续读取或写入。
      }
    }
    throw toAppError(error as Error, AppErrorCode.DATABASE_INIT, '数据库初始化失败，请重试');
  }
}

export class RdbDatabase {
  private readonly context: Context;
  private store?: relationalStore.RdbStore;
  private initializing?: Promise<Result<relationalStore.RdbStore>>;

  constructor(context: Context) {
    this.context = context;
  }

  async getStore(): Promise<Result<relationalStore.RdbStore>> {
    if (this.store !== undefined) {
      return success(this.store);
    }
    if (this.initializing === undefined) {
      this.initializing = this.openAndInitialize();
    }
    return this.initializing;
  }

  async requireStore(): Promise<relationalStore.RdbStore> {
    const result = await this.getStore();
    if (!result.ok) {
      throw result.getError();
    }
    return result.getData();
  }

  async transaction<T>(operation: (store: relationalStore.RdbStore) => Promise<T>): Promise<T> {
    const store = await this.requireStore();
    let started = false;
    try {
      store.beginTransaction();
      started = true;
      const value = await operation(store);
      store.commit();
      return value;
    } catch (error) {
      if (started) {
        try {
          store.rollBack();
        } catch (_) {
          // 回滚失败不覆盖原始领域错误。
        }
      }
      throw toAppError(error as Error, AppErrorCode.DATABASE_INIT, '数据库初始化失败，请重试');
    }
  }

  close(): void {
    if (this.store !== undefined) {
      this.store.close();
      this.store = undefined;
      this.initializing = undefined;
    }
  }

  private async openAndInitialize(): Promise<Result<relationalStore.RdbStore>> {
    try {
      const config: relationalStore.StoreConfig = {
        name: DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S3
      };
      const store = await relationalStore.getRdbStore(this.context, config);
      await migrateToV1(store);
      this.store = store;
      return success(store);
    } catch (error) {
      return failure<relationalStore.RdbStore>(toAppError(error, AppErrorCode.DATABASE_INIT, '数据库初始化失败，请重试'));
    }
  }

}
