export enum AppErrorCode {
  VALIDATION = 'VALIDATION',
  DATABASE_INIT = 'DATABASE_INIT',
  DATABASE_READ = 'DATABASE_READ',
  DATABASE_WRITE = 'DATABASE_WRITE',
  NOT_FOUND = 'NOT_FOUND',
  ROUTE_INVALID = 'ROUTE_INVALID',
  UNKNOWN = 'UNKNOWN'
}

export class AppError extends Error {
  readonly code: AppErrorCode;

  constructor(code: AppErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

export function toAppError(error: Error | AppError, fallbackCode: AppErrorCode, fallbackMessage: string): AppError {
  if (error instanceof AppError) {
    return error;
  }
  return new AppError(fallbackCode, fallbackMessage);
}
