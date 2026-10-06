import { ExternalRequest } from '../model/SystemFeatures';
import { ItemQuery } from '../model/ItemQuery';
import { AppServices } from '../service/AppServices';
import { NavigationHelper, NavigationOptions } from './NavigationHelper';
import { RouteName } from './RouteName';

export class ExternalNavigation {
  static async open(request: ExternalRequest): Promise<boolean> {
    if (AppStorage.get<boolean>('itemtrace.backupActive') && request.action !== 'backup') {
      throw new Error('备份或恢复正在执行，请完成后再操作物品');
    }
    let options: NavigationOptions;
    if (request.action === 'item') {
      options = { url: RouteName.ITEM_DETAIL, params: { itemId: request.itemId } };
    } else if (request.action === 'location') {
      const location = await AppServices.get().locationLabels.resolve(request.locationId ?? '');
      options = { url: RouteName.ITEM_LIST, params: { query: new ItemQuery('', location.path), locationId: location.id } };
    } else if (request.action === 'search') {
      options = { url: RouteName.SEARCH, params: { query: new ItemQuery(request.name ?? '', request.locationPath) } };
    } else if (request.action === 'add' || request.action === 'scan' || request.action === 'camera') {
      options = { url: RouteName.ITEM_FORM, params: { mode: 'create', source: request.action === 'add' ? 'manual' : request.action,
        externalRequest: request, returnTo: RouteName.HOME } };
    } else if (request.action === 'expiry' || request.action === 'reminders') {
      options = { url: RouteName.ITEM_LIST, params: { attention: request.action } };
    } else if (request.action === 'loans') {
      options = { url: RouteName.OUTSTANDING_LOANS };
    } else if (request.action === 'backup') {
      options = { url: RouteName.SETTINGS, params: { section: 'backup' } };
    } else if (request.action === 'system') {
      options = { url: RouteName.SYSTEM_FEATURES };
    } else if (['consume', 'borrow', 'return'].includes(request.action)) {
      options = { url: RouteName.ITEM_ACTION, params: { externalRequest: request } };
    } else { throw new Error('无法识别这个操作入口'); }
    return NavigationHelper.pushUrl(options);
  }
}
