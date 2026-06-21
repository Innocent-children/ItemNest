import { Result } from '../common/Result';
import { ExportService } from './ExportService';

export class BackupService {
  private readonly exportService: ExportService;

  constructor(exportService: ExportService) {
    this.exportService = exportService;
  }

  async createLocalBackupJson(): Promise<Result<string>> {
    return this.exportService.exportJson();
  }
}
