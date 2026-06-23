export const DATA_REVISION_KEY: string = 'itemtrace.dataRevision';
export const PREFERENCE_REVISION_KEY: string = 'itemtrace.preferenceRevision';

type AppEventListener = () => void;

export class AppEventBus {
  private static nextListenerId: number = 1;
  private static dataListeners: Map<number, AppEventListener> = new Map<number, AppEventListener>();

  static notifyDataChanged(): number {
    return AppEventBus.emitDataChanged();
  }

  static currentDataRevision(): number {
    return AppStorage.get<number>(DATA_REVISION_KEY) ?? 0;
  }

  static currentPreferenceRevision(): number {
    return AppStorage.get<number>(PREFERENCE_REVISION_KEY) ?? 0;
  }

  private static emitDataChanged(): number {
    const revision = AppEventBus.increment(DATA_REVISION_KEY);
    AppEventBus.notifyListeners(AppEventBus.dataListeners);
    return revision;
  }

  static notifyPreferencesChanged(): number {
    return AppEventBus.increment(PREFERENCE_REVISION_KEY);
  }

  static subscribeDataChanged(listener: AppEventListener): number {
    const listenerId = AppEventBus.nextListenerId++;
    AppEventBus.dataListeners.set(listenerId, listener);
    return listenerId;
  }

  static unsubscribeDataChanged(listenerId: number): void {
    AppEventBus.dataListeners.delete(listenerId);
  }

  private static increment(key: string): number {
    const current = AppStorage.get<number>(key) ?? 0;
    const next = current + 1;
    try {
      AppStorage.set<number>(key, next);
    } catch (_) {
      AppStorage.setOrCreate<number>(key, next);
    }
    return next;
  }

  private static notifyListeners(listeners: Map<number, AppEventListener>): void {
    listeners.forEach((listener: AppEventListener) => {
      try {
        listener();
      } catch (_) {
      }
    });
  }
}
