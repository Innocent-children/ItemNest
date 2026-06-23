import { relationalStore } from '@kit.ArkData';
import { AppErrorCode, toAppError } from '../../common/AppError';

export class ResultSetReader {
  static goToFirstRow(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.goToFirstRow();
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_READ, '读取数据库结果失败，请重试');
    }
  }

  static goToNextRow(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.goToNextRow();
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_READ, '读取数据库结果失败，请重试');
    }
  }

  static readString(resultSet: relationalStore.ResultSet, column: string): string | undefined {
    try {
      const index = resultSet.getColumnIndex(column);
      return resultSet.isColumnNull(index) ? undefined : resultSet.getString(index);
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_READ, '读取数据库文本字段失败，请重试');
    }
  }

  static readDouble(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    try {
      const index = resultSet.getColumnIndex(column);
      return resultSet.isColumnNull(index) ? undefined : resultSet.getDouble(index);
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_READ, '读取数据库数值字段失败，请重试');
    }
  }

  static readLong(resultSet: relationalStore.ResultSet, column: string): number | undefined {
    try {
      const index = resultSet.getColumnIndex(column);
      return resultSet.isColumnNull(index) ? undefined : resultSet.getLong(index);
    } catch (error) {
      throw toAppError(error as Error, AppErrorCode.DATABASE_READ, '读取数据库整数字段失败，请重试');
    }
  }

  static close(resultSet: relationalStore.ResultSet): void {
    try {
      resultSet.close();
    } catch (_) {
    }
  }
}
