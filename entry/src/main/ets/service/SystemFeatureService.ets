import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SystemFeatures } from '../model/SystemFeatures';

export class SystemFeatureService {
  private context: Context;
  private store?: preferences.Preferences;

  constructor(context: Context) {
    this.context = context;
  }

  private async storage(): Promise<preferences.Preferences> {
    if (this.store === undefined) {
      this.store = await preferences.getPreferences(this.context, 'itemtrace_system_features');
    }
    return this.store;
  }

  async get(): Promise<SystemFeatures> {
    const store = await this.storage();
    return {
      assistantEnabled: store.getSync('assistantEnabled', false) === true,
      searchEnabled: store.getSync('searchEnabled', false) === true,
      searchLocationVisible: store.getSync('searchLocationVisible', false) === true,
      photoSearchEnabled: store.getSync('photoSearchEnabled', true) === true,
      liveViewEnabled: store.getSync('liveViewEnabled', false) === true
    };
  }

  async save(value: SystemFeatures): Promise<void> {
    const store = await this.storage();
    await store.put('assistantEnabled', value.assistantEnabled);
    await store.put('searchEnabled', value.searchEnabled);
    await store.put('searchLocationVisible', value.searchLocationVisible);
    await store.put('photoSearchEnabled', value.photoSearchEnabled);
    await store.put('liveViewEnabled', value.liveViewEnabled);
    await store.flush();
  }
}
