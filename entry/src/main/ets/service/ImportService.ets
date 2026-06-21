import { AppError, AppErrorCode } from '../common/AppError';
import { ImportPreview, ImportValidation } from '../common/ImportValidation';
import { failure, Result, success } from '../common/Result';

export class ImportService {
  private readonly validation: ImportValidation;

  constructor(validation: ImportValidation = new ImportValidation()) {
    this.validation = validation;
  }

  preview(text: string): Result<ImportPreview> {
    const payload = this.validation.validate(text);
    if (!payload.ok) {
      return failure<ImportPreview>(payload.getError());
    }
    return success(this.validation.preview(payload.getData()));
  }

  confirmImport(text: string, confirmed: boolean): Result<ImportPreview> {
    if (!confirmed) {
      return failure<ImportPreview>(new AppError(AppErrorCode.VALIDATION, '导入前需要用户确认'));
    }
    const preview = this.preview(text);
    if (!preview.ok) {
      return preview;
    }
    return preview;
  }
}
