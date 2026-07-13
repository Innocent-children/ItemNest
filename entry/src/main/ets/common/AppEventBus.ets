export const DATA_REVISION_KEY: string = 'itemtrace.dataRevision';
export const PREFERENCE_REVISION_KEY: string = 'itemtrace.preferenceRevision';

type AppEventListener = () => void;

export class AppEventBus {
  private static nextListenerId: number = 1;
  private static dataListeners: Map<number, AppEventListener> = new Map<number, AppEventListener>();
  private static dataRevision: number = 0;
  private static preferenceRevision: number = 0;

  static notifyDataChanged(): number {
    return AppEventBus.emitDataChanged();
  }

  static currentDataRevision(): number {
    return AppEventBus.readRevision(DATA_REVISION_KEY);
  }

  static currentPreferenceRevision(): number {
    return AppEventBus.readRevision(PREFERENCE_REVISION_KEY);
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
    const current = AppEventBus.readRevision(key);
    const next = current + 1;
    AppEventBus.cacheRevision(key, next);
    try {
      AppStorage.set<number>(key, next);
    } catch (_) {
      try {
        AppStorage.setOrCreate<number>(key, next);
      } catch (_) {
        // 非 UI 测试环境可能没有可用的 AppStorage，内存 revision 仍可驱动订阅者。
      }
    }
    return next;
  }

  private static readRevision(key: string): number {
    try {
      const stored = AppStorage.get<number>(key);
      if (stored !== undefined) {
        AppEventBus.cacheRevision(key, stored);
        return stored;
      }
    } catch (_) {
      // Ability 尚未创建或本地测试无 AppStorage 时使用进程内缓存。
    }
    return key === DATA_REVISION_KEY ? AppEventBus.dataRevision : AppEventBus.preferenceRevision;
  }

  private static cacheRevision(key: string, revision: number): void {
    if (key === DATA_REVISION_KEY) {
      AppEventBus.dataRevision = revision;
      return;
    }
    AppEventBus.preferenceRevision = revision;
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
