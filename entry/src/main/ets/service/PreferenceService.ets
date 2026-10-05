import { AppError, AppErrorCode } from '../common/AppError';
import { failure, Result } from '../common/Result';
import { PreferenceRepositoryPort } from '../data/repository/PreferenceRepository';
import { DEFAULT_USER_PREFERENCES, UserPreferences } from '../model/UserPreferences';

export class PreferenceService {
  private readonly repository: PreferenceRepositoryPort;
  private saveQueue: Promise<void> = Promise.resolve();

  constructor(repository: PreferenceRepositoryPort) {
    this.repository = repository;
  }

  async get(): Promise<Result<UserPreferences>> {
    await this.saveQueue;
    return this.repository.get();
  }

  async save(preferences: UserPreferences): Promise<Result<UserPreferences>> {
    if (!Number.isInteger(preferences.defaultReminderDays) || preferences.defaultReminderDays < 0 || preferences.defaultReminderDays > 365) {
      return failure<UserPreferences>(new AppError(AppErrorCode.VALIDATION, '默认提前提醒天数应为 0 到 365 的整数'));
    }
    const snapshot: UserPreferences = {
      defaultReminderDays: preferences.defaultReminderDays, defaultSort: preferences.defaultSort,
      showRecentSection: preferences.showRecentSection, showExpirySection: preferences.showExpirySection,
      showStockSection: preferences.showStockSection, themeMode: preferences.themeMode,
      reminderEnabled: preferences.reminderEnabled
    };
    const previous = this.saveQueue;
    let release: () => void = () => {};
    this.saveQueue = new Promise<void>((resolve: () => void) => { release = resolve; });
    await previous;
    try {
      return await this.repository.save(snapshot);
    } finally {
      release();
    }
  }

  createDefault(): UserPreferences {
    return {
      defaultReminderDays: DEFAULT_USER_PREFERENCES.defaultReminderDays,
      defaultSort: DEFAULT_USER_PREFERENCES.defaultSort,
      showRecentSection: DEFAULT_USER_PREFERENCES.showRecentSection,
      showExpirySection: DEFAULT_USER_PREFERENCES.showExpirySection,
      showStockSection: DEFAULT_USER_PREFERENCES.showStockSection,
      themeMode: DEFAULT_USER_PREFERENCES.themeMode,
      reminderEnabled: DEFAULT_USER_PREFERENCES.reminderEnabled
    };
  }
}
