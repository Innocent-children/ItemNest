import { ImportPreview } from '../common/ImportValidation';
import { Result } from '../common/Result';
import { ImportService } from './ImportService';

export class RestoreService {
  private readonly importService: ImportService;

  constructor(importService: ImportService) {
    this.importService = importService;
  }

  previewRestore(text: string): Result<ImportPreview> {
    return this.importService.preview(text);
  }

  confirmRestore(text: string, confirmed: boolean): Result<ImportPreview> {
    return this.importService.confirmImport(text, confirmed);
  }
}
