import { AppError, AppErrorCode } from './AppError';
import { failure, Result, success } from './Result';
import { Category, isCategory } from '../model/Category';
import { ItemDraft, isItemUnit, ItemUnit } from '../model/Item';
import { LOCATION_PATH_MAX_LENGTH, normalizeLocationPath } from '../model/LocationPath';

export class ValidatedItemDraft {
  readonly name: string;
  readonly quantity: number;
  readonly unit: ItemUnit;
  readonly locationPath?: string;
  readonly category?: Category;
  readonly expirationDate?: string;
  readonly reminderDays?: number;
  readonly notes?: string;

  constructor(name: string, quantity: number, unit: ItemUnit, locationPath?: string, category?: Category,
    expirationDate?: string, reminderDays?: number, notes?: string) {
    this.name = name;
    this.quantity = quantity;
    this.unit = unit;
    this.locationPath = locationPath;
    this.category = category;
    this.expirationDate = expirationDate;
    this.reminderDays = reminderDays;
    this.notes = notes;
  }
}

const NAME_MAX_LENGTH: number = 80;
const NOTES_MAX_LENGTH: number = 500;

export class ItemValidator {
  validate(draft: ItemDraft): Result<ValidatedItemDraft> {
    const nameResult = this.validateName(draft.name);
    if (!nameResult.ok) {
      return failure<ValidatedItemDraft>(nameResult.getError());
    }

    const quantityResult = this.validateQuantity(draft.quantity);
    if (!quantityResult.ok) {
      return failure<ValidatedItemDraft>(quantityResult.getError());
    }

    const unitResult = this.validateUnit(draft.unit);
    if (!unitResult.ok) {
      return failure<ValidatedItemDraft>(unitResult.getError());
    }

    const locationResult = this.validateLocationPath(draft.locationPath);
    if (!locationResult.ok) {
      return failure<ValidatedItemDraft>(locationResult.getError());
    }

    const categoryResult = this.validateCategory(draft.category);
    if (!categoryResult.ok) {
      return failure<ValidatedItemDraft>(categoryResult.getError());
    }

    const expirationResult = this.validateExpirationDate(draft.expirationDate);
    if (!expirationResult.ok) {
      return failure<ValidatedItemDraft>(expirationResult.getError());
    }

    const reminderResult = this.validateReminderDays(draft.reminderDays);
    if (!reminderResult.ok) {
      return failure<ValidatedItemDraft>(reminderResult.getError());
    }

    const notesResult = this.validateNotes(draft.notes);
    if (!notesResult.ok) {
      return failure<ValidatedItemDraft>(notesResult.getError());
    }

    return success(new ValidatedItemDraft(
      nameResult.getData(), quantityResult.getData(), unitResult.getData(), locationResult.getData(),
      categoryResult.getData(), expirationResult.getData(), reminderResult.getData(), notesResult.getData()
    ));
  }

  validateName(value?: string): Result<string> {
    const normalized = value?.trim() ?? '';
    if (normalized.length === 0 || normalized.length > NAME_MAX_LENGTH) {
      return failure<string>(new AppError(AppErrorCode.VALIDATION, '物品名称需为 1 至 80 个字符'));
    }
    return success(normalized);
  }

  validateQuantity(value?: number): Result<number> {
    const quantity = value ?? 1;
    if (!Number.isFinite(quantity) || quantity < 0 || Math.round(quantity * 100) !== quantity * 100) {
      return failure<number>(new AppError(AppErrorCode.VALIDATION, '数量必须是最多两位小数的非负数'));
    }
    return success(quantity);
  }

  validateUnit(value?: ItemUnit): Result<ItemUnit> {
    const unit = value ?? ItemUnit.PIECE;
    if (!isItemUnit(unit)) {
      return failure<ItemUnit>(new AppError(AppErrorCode.VALIDATION, '请选择有效的物品单位'));
    }
    return success(unit);
  }

  validateLocationPath(value?: string): Result<string | undefined> {
    const normalized = normalizeLocationPath(value);
    if (normalized !== undefined && normalized.length > LOCATION_PATH_MAX_LENGTH) {
      return failure<string | undefined>(new AppError(AppErrorCode.VALIDATION, '位置路径不能超过 200 个字符'));
    }
    return success(normalized);
  }

  validateCategory(value?: Category): Result<Category | undefined> {
    if (value === undefined || value.length === 0) {
      return success(undefined);
    }
    if (!isCategory(value)) {
      return failure<Category | undefined>(new AppError(AppErrorCode.VALIDATION, '请选择有效的物品分类'));
    }
    return success(value as Category);
  }

  validateExpirationDate(value?: string): Result<string | undefined> {
    if (value === undefined || value.length === 0) {
      return success(undefined);
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return failure<string | undefined>(new AppError(AppErrorCode.VALIDATION, '到期日期格式应为 YYYY-MM-DD'));
    }
    const date = new Date(`${value}T00:00:00`);
    const valid = !Number.isNaN(date.getTime()) &&
      date.getFullYear() === Number(value.substring(0, 4)) &&
      date.getMonth() + 1 === Number(value.substring(5, 7)) &&
      date.getDate() === Number(value.substring(8, 10));
    if (!valid) {
      return failure<string | undefined>(new AppError(AppErrorCode.VALIDATION, '到期日期无效'));
    }
    return success(value);
  }

  validateReminderDays(value?: number): Result<number | undefined> {
    if (value === undefined) {
      return success(undefined);
    }
    if (!Number.isInteger(value) || value < 0 || value > 365) {
      return failure<number | undefined>(new AppError(AppErrorCode.VALIDATION, '提前提醒天数必须是 0 至 365 的整数'));
    }
    return success(value);
  }

  validateNotes(value?: string): Result<string | undefined> {
    if (value === undefined || value.length === 0) {
      return success(undefined);
    }
    if (value.length > NOTES_MAX_LENGTH) {
      return failure<string | undefined>(new AppError(AppErrorCode.VALIDATION, '注意事项不能超过 500 个字符'));
    }
    return success(value);
  }
}
