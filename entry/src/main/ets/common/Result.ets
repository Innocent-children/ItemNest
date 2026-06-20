import { AppError, AppErrorCode } from './AppError';

export class Result<T> {
  readonly ok: boolean;
  private readonly value?: T;
  private readonly appError?: AppError;

  constructor(ok: boolean, value?: T, error?: AppError) {
    this.ok = ok;
    this.value = value;
    this.appError = error;
  }

  getData(): T {
    if (!this.ok) {
      throw new AppError(this.appError?.code ?? AppErrorCode.UNKNOWN, '结果不包含成功数据');
    }
    return this.value as T;
  }

  getError(): AppError {
    if (this.ok || this.appError === undefined) {
      return new AppError(AppErrorCode.UNKNOWN, '结果不包含失败信息');
    }
    return this.appError;
  }
}

export function success<T>(data: T): Result<T> {
  return new Result<T>(true, data);
}

export function failure<T>(error: AppError): Result<T> {
  return new Result<T>(false, undefined, error);
}
