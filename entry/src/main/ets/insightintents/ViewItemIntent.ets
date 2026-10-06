import { InsightIntentEntry, InsightIntentEntryExecutor, insightIntent } from '@kit.AbilityKit';
import { AppServices } from '../service/AppServices';
import { ItemIntentEntity } from './ItemIntentEntity';
import { ExternalRequestParser } from '../navigation/ExternalRequestParser';

@InsightIntentEntry({
  intentName: 'ViewStoredItem', domain: 'ToolsDomain', intentVersion: '1.0.0',
  displayName: '查看已记录物品', displayDescription: '搜索本机物品并打开详情',
  llmDescription: '通过实时查询的物品实体打开 ItemTrace 物品详情。', keywords: ['找物品', '物品详情'],
  abilityName: 'EntryAbility', executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: { type: 'object', properties: { item: { type: 'object', description: '要查看的物品',
    properties: { entityId: { type: 'string' }, name: { type: 'string' }, displayName: { type: 'string' }, location: { type: 'string' } },
    required: ['entityId', 'name', 'displayName'] } }, required: ['item'] }
})
export default class ViewItemIntent extends InsightIntentEntryExecutor<string> {
  public item?: ItemIntentEntity;
  async onExecute(): Promise<insightIntent.IntentResult<string>> {
    try {
      const services = AppServices.get();
      if (!(await services.systemFeatures.get()).searchEnabled) { return { code: -1, result: '系统物品搜索未开启。' }; }
      const result = await services.detailItem.getDetail(this.item?.entityId ?? '');
      if (!result.ok) { return { code: -1, result: '物品已删除或暂时无法读取。' }; }
      ExternalRequestParser.publish({ action: 'item', itemId: result.getData().id });
      return { code: 0, result: '已打开物品详情。' };
    } catch (_) { return { code: -1, result: '无法打开物品详情。' }; }
  }
}
