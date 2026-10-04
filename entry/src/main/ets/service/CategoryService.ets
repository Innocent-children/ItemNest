import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result } from '../common/Result';
import { CategoryDraft, CategoryRecord, createCategoryId } from '../model/Category';
import { CategoryRepository } from '../data/repository/CategoryRepository';

export class CategoryService {
  private readonly categories: CategoryRepository;
  private readonly clock: () => number;

  constructor(categories: CategoryRepository, clock: () => number = () => Date.now()) {
    this.categories = categories;
    this.clock = clock;
  }

  async list(): Promise<Result<CategoryRecord[]>> {
    return this.categories.listAll();
  }

  async create(draft: CategoryDraft): Promise<Result<CategoryRecord>> {
    const name = draft.name?.trim() ?? '';
    if (name.length === 0 || name.length > 40) {
      return failure<CategoryRecord>(new AppError(AppErrorCode.VALIDATION, '分类名称需为 1 至 40 个字符'));
    }
    const categoriesResult = await this.categories.listAll();
    if (!categoriesResult.ok) {
      return failure<CategoryRecord>(categoriesResult.getError());
    }
    for (const category of categoriesResult.getData()) {
      if (category.name === name) {
        return failure<CategoryRecord>(new AppError(AppErrorCode.VALIDATION,
          '该分类已存在，可在列表中启用或改用其他名称'));
      }
    }
    const now = this.clock();
    return this.categories.create({
      id: createCategoryId(this.clock),
      name: name,
      active: true,
      systemPreset: false,
      createdAt: now,
      updatedAt: now
    });
  }

  async setActive(categoryId: string, active: boolean): Promise<Result<void>> {
    return this.categories.setActive(categoryId, active, this.clock());
  }
}
