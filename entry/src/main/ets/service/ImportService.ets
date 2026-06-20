import { AppError } from '../common/AppError';
import { Result } from '../common/Result';
import { ItemRepository } from '../data/repository/ItemRepository';

export class ImportService {
  constructor(private itemRepo: ItemRepository) { }

  validate(json: string): Result<ImportPreview> {
    try {
      const data = JSON.parse(json);
      if (!data.items || !Array.isArray(data.items)) {
        return Result.failure(AppError.of('INVALID_FORMAT', '无效的导入文件格式'));
      }
      const count = data.items.length;
      return Result.success({ version: data.version ?? 1, itemCount: count });
    } catch (err) {
      return Result.failure(AppError.of('INVALID_JSON', '文件不是有效的 JSON'));
    }
  }
}

export interface ImportPreview {
  version: number;
  itemCount: number;
}
