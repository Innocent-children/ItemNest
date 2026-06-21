export const DATA_REVISION_KEY: string = 'itemtrace.dataRevision';
export const PREFERENCE_REVISION_KEY: string = 'itemtrace.preferenceRevision';

export class AppEventBus {
  static notifyDataChanged(): void {
    AppEventBus.increment(DATA_REVISION_KEY);
  }

  static notifyPreferencesChanged(): void {
    AppEventBus.increment(PREFERENCE_REVISION_KEY);
  }

  private static increment(key: string): void {
    const current = AppStorage.get<number>(key) ?? 0;
    AppStorage.setOrCreate<number>(key, current + 1);
  }
}
