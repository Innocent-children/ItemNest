import { relationalStore } from '@kit.ArkData';
import { AppErrorCode, toAppError } from '../../common/AppError';

export class SchemaExecutor {
  static async execute(store: relationalStore.Transaction, sql: string): Promise<void> {
    try {
      await store.execute(sql);
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_INIT, '数据库结构初始化失败，请重试');
    }
  }
}
