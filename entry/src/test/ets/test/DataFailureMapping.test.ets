import { describe, it, expect } from '@ohos/hypium';
import { AppError, AppErrorCode, toAppError } from '../../../main/ets/common/AppError';

export default function dataFailureMappingTest() {
  describe('Data failure mapping', () => {
    it('数据库读取异常映射为可展示的读取错误', 0, () => {
      const error = toAppError(new Error('raw rdb read error'), AppErrorCode.DATABASE_READ, '读取数据库失败，请重试');

      expect(error.code).assertEqual(AppErrorCode.DATABASE_READ);
      expect(error.message).assertEqual('读取数据库失败，请重试');
    });

    it('数据库初始化异常映射为初始化错误', 0, () => {
      const error = toAppError(new Error('raw schema error'), AppErrorCode.DATABASE_INIT, '数据库结构初始化失败，请重试');

      expect(error.code).assertEqual(AppErrorCode.DATABASE_INIT);
      expect(error.message).assertEqual('数据库结构初始化失败，请重试');
    });

    it('已经归一化的 AppError 不会被覆盖', 0, () => {
      const original = new AppError(AppErrorCode.DATABASE_WRITE, '保存失败，请重试');
      const error = toAppError(original, AppErrorCode.UNKNOWN, '未知错误');

      expect(error.code).assertEqual(AppErrorCode.DATABASE_WRITE);
      expect(error.message).assertEqual('保存失败，请重试');
    });
  });
}
