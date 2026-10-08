import { AppError, AppErrorCode } from '../common/AppError';

export function reminderPublishFailure(code: number, validCount?: number): AppError {
  if (code === 201) {
    return new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED, '当前应用尚不能使用系统到期通知；到期日期已保留，可在应用内查看。');
  }
  if (code === 1700001) {
    return new AppError(AppErrorCode.SYSTEM_PERMISSION_DENIED, '系统通知未授权，请在通知设置中允许后重试。');
  }
  if (code === 1700002) {
    const message = validCount === 0 ?
      '当前设备尚不能为本应用创建到期通知。到期日期已保留，可在应用内查看；稍后可重新检查。' :
      `系统限制了新增到期通知${validCount === undefined ? '' : `（本应用当前有 ${validCount} 条）`}。到期日期已保留，可在应用内查看。`;
    return new AppError(AppErrorCode.REMINDER_DISPATCH, message);
  }
  return new AppError(AppErrorCode.REMINDER_DISPATCH, '系统提醒创建失败，请稍后重试。');
}
