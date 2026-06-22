export const DATA_REVISION_KEY: string = 'itemtrace.dataRevision';
export const PREFERENCE_REVISION_KEY: string = 'itemtrace.preferenceRevision';

type AppEventListener = () => void;

export class AppEventBus {
  private static nextListenerId: number = 1;
  private static dataListeners: Map<number, AppEventListener> = new Map<number, AppEventListener>();

  static notifyDataChanged(): void {
    AppEventBus.emitDataChanged();
    setTimeout(() => AppEventBus.emitDataChanged(), 300);
  }

  private static emitDataChanged(): void {
    AppEventBus.increment(DATA_REVISION_KEY);
    AppEventBus.notifyListeners(AppEventBus.dataListeners);
  }

  static notifyPreferencesChanged(): void {
    AppEventBus.increment(PREFERENCE_REVISION_KEY);
  }

  static subscribeDataChanged(listener: AppEventListener): number {
    const listenerId = AppEventBus.nextListenerId++;
    AppEventBus.dataListeners.set(listenerId, listener);
    return listenerId;
  }

  static unsubscribeDataChanged(listenerId: number): void {
    AppEventBus.dataListeners.delete(listenerId);
  }

  private static increment(key: string): void {
    const current = AppStorage.get<number>(key) ?? 0;
    try {
      AppStorage.set<number>(key, current + 1);
    } catch (_) {
      AppStorage.setOrCreate<number>(key, current + 1);
    }
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
