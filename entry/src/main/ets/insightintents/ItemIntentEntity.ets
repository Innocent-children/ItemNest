import { insightIntent, InsightIntentEntity } from '@kit.AbilityKit';
import { AppServices } from '../service/AppServices';
import { ItemQuery } from '../model/ItemQuery';

@InsightIntentEntity({
  entityCategory: 'itemnest_item',
  parameters: {
    '$id': '/schemas/ItemIntentEntity', type: 'object', description: '已记录的个人物品',
    properties: {
      entityId: { type: 'string', title: '物品标识', description: '物品的唯一标识' },
      name: { type: 'string', title: '物品名称', description: '用户记录的物品名称' },
      displayName: { type: 'string', description: '物品显示名称' },
      location: { type: 'string', description: '用户允许显示时返回记录的位置' }
    }, required: ['entityId', 'name', 'displayName']
  },
  supportedQueryProperties: ['entityId', 'name']
})
export class ItemIntentEntity extends insightIntent.AppIntentEntity<ItemIntentEntity> {
  public entityId: string = 'itemnest-item';
  public name: string = '';
  public displayName: string = '';
  public location: string = '';

  async onQueryEntity(params: insightIntent.QueryEntityParam): Promise<ItemIntentEntity[]> {
    const services = AppServices.get();
    const settings = await services.systemFeatures.get();
    if (!settings.searchEnabled) { return []; }
    const input = params.parameters;
    const id = typeof input?.['entityId'] === 'string' ? input['entityId'] as string : '';
    const name = typeof input?.['name'] === 'string' ? input['name'] as string : '';
    if (params.queryType !== insightIntent.QueryType.ALL && id.length === 0 && name.length === 0) { return []; }
    const result = await services.searchItems.search(new ItemQuery(name));
    if (!result.ok) { throw result.getError(); }
    const entities: ItemIntentEntity[] = [];
    for (const item of result.getData().items) {
      if (id.length > 0 && item.id !== id) { continue; }
      const entity = new ItemIntentEntity();
      entity.entityId = item.id; entity.name = item.name; entity.displayName = item.name;
      entity.location = settings.searchLocationVisible ? (item.activeLocationPaths?.join('、') || item.locationPath || '') : '';
      entities.push(entity);
    }
    return entities;
  }
}
