import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppErrorCode, toAppError } from '../../common/AppError';
import { failure, Result, success } from '../../common/Result';
import { DEFAULT_USER_PREFERENCES, ItemSortMode, ThemeMode, UserPreferences } from '../../model/UserPreferences';

const PREFERENCES_NAME = 'itemtrace_user_preferences';
const KEY_DEFAULT_REMINDER_DAYS = 'defaultReminderDays';
const KEY_DEFAULT_SORT = 'defaultSort';
const KEY_SHOW_RECENT = 'showRecentSection';
const KEY_SHOW_EXPIRY = 'showExpirySection';
const KEY_SHOW_STOCK = 'showStockSection';
const KEY_THEME_MODE = 'themeMode';
const KEY_REMINDER_ENABLED = 'reminderEnabled';

export interface PreferenceRepositoryPort {
  get(): Promise<Result<UserPreferences>>;
  save(userPreferences: UserPreferences): Promise<Result<UserPreferences>>;
}

export class PreferenceRepository implements PreferenceRepositoryPort {
  private readonly context: Context;
  private store?: preferences.Preferences;

  constructor(context: Context) {
    this.context = context;
  }

  async get(): Promise<Result<UserPreferences>> {
    try {
      const store = await this.requireStore();
      const userPreferences: UserPreferences = {
        defaultReminderDays: this.readReminderDays(store.getSync(KEY_DEFAULT_REMINDER_DAYS, DEFAULT_USER_PREFERENCES.defaultReminderDays)),
        defaultSort: this.readSortMode(store.getSync(KEY_DEFAULT_SORT, DEFAULT_USER_PREFERENCES.defaultSort)),
        showRecentSection: this.readBoolean(store.getSync(KEY_SHOW_RECENT, DEFAULT_USER_PREFERENCES.showRecentSection), DEFAULT_USER_PREFERENCES.showRecentSection),
        showExpirySection: this.readBoolean(store.getSync(KEY_SHOW_EXPIRY, DEFAULT_USER_PREFERENCES.showExpirySection), DEFAULT_USER_PREFERENCES.showExpirySection),
        showStockSection: this.readBoolean(store.getSync(KEY_SHOW_STOCK, DEFAULT_USER_PREFERENCES.showStockSection), DEFAULT_USER_PREFERENCES.showStockSection),
        themeMode: this.readThemeMode(store.getSync(KEY_THEME_MODE, DEFAULT_USER_PREFERENCES.themeMode)),
        reminderEnabled: this.readBoolean(store.getSync(KEY_REMINDER_ENABLED, DEFAULT_USER_PREFERENCES.reminderEnabled), DEFAULT_USER_PREFERENCES.reminderEnabled)
      };
      return success<UserPreferences>(userPreferences);
    } catch (error) {
      return failure<UserPreferences>(toAppError(error, AppErrorCode.PREFERENCE_READ, '读取偏好设置失败，请重试'));
    }
  }

  async save(userPreferences: UserPreferences): Promise<Result<UserPreferences>> {
    try {
      const store = await this.requireStore();
      await store.put(KEY_DEFAULT_REMINDER_DAYS, userPreferences.defaultReminderDays);
      await store.put(KEY_DEFAULT_SORT, userPreferences.defaultSort);
      await store.put(KEY_SHOW_RECENT, userPreferences.showRecentSection);
      await store.put(KEY_SHOW_EXPIRY, userPreferences.showExpirySection);
      await store.put(KEY_SHOW_STOCK, userPreferences.showStockSection);
      await store.put(KEY_THEME_MODE, userPreferences.themeMode);
      await store.put(KEY_REMINDER_ENABLED, userPreferences.reminderEnabled);
      await store.flush();
      return success(userPreferences);
    } catch (error) {
      return failure<UserPreferences>(toAppError(error, AppErrorCode.PREFERENCE_WRITE, '保存偏好设置失败，请重试'));
    }
  }

  private async requireStore(): Promise<preferences.Preferences> {
    if (this.store === undefined) {
      this.store = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    }
    return this.store;
  }

  private readReminderDays(value: preferences.ValueType): number {
    if (typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 365) {
      return value;
    }
    return DEFAULT_USER_PREFERENCES.defaultReminderDays;
  }

  private readBoolean(value: preferences.ValueType, fallback: boolean): boolean {
    return typeof value === 'boolean' ? value : fallback;
  }

  private readSortMode(value: preferences.ValueType): ItemSortMode {
    if (value === ItemSortMode.UPDATED_DESC || value === ItemSortMode.CREATED_DESC || value === ItemSortMode.NAME_ASC) {
      return value;
    }
    return DEFAULT_USER_PREFERENCES.defaultSort;
  }

  private readThemeMode(value: preferences.ValueType): ThemeMode {
    if (value === ThemeMode.SYSTEM || value === ThemeMode.LIGHT || value === ThemeMode.DARK) {
      return value;
    }
    return DEFAULT_USER_PREFERENCES.themeMode;
  }
}
