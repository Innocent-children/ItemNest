export enum ItemSortMode {
  UPDATED_DESC = 'UPDATED_DESC',
  CREATED_DESC = 'CREATED_DESC',
  NAME_ASC = 'NAME_ASC'
}

export enum ThemeMode {
  SYSTEM = 'SYSTEM',
  LIGHT = 'LIGHT',
  DARK = 'DARK'
}

export interface UserPreferences {
  defaultReminderDays: number;
  defaultSort: ItemSortMode;
  showRecentSection: boolean;
  showExpirySection: boolean;
  showStockSection: boolean;
  themeMode: ThemeMode;
  reminderEnabled: boolean;
}

export const DEFAULT_USER_PREFERENCES: UserPreferences = {
  defaultReminderDays: 7,
  defaultSort: ItemSortMode.UPDATED_DESC,
  showRecentSection: true,
  showExpirySection: true,
  showStockSection: true,
  themeMode: ThemeMode.SYSTEM,
  reminderEnabled: false
};
