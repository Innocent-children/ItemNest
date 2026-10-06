import { InsightIntentEntry, InsightIntentEntryExecutor, insightIntent } from '@kit.AbilityKit';
import { AppServices } from '../service/AppServices';
import { ExternalRequestParser } from '../navigation/ExternalRequestParser';

@InsightIntentEntry({
  intentName: 'RecordStoredItem', domain: 'ToolsDomain', intentVersion: '1.0.0',
  displayName: '记录物品变化', displayDescription: '填写新增物品、消耗、借出或归还草稿，在应用内确认保存',
  llmDescription: '为用户新增物品或记录消耗、借出、归还。action 为 add、consume、borrow、return。只打开待确认草稿，不表示已保存。不得猜测名称、数量和借用人。',
  keywords: ['记下物品', '用掉物品', '借给', '归还'], abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_FOREGROUND],
  parameters: { type: 'object', properties: {
    action: { type: 'string', enum: ['add', 'consume', 'borrow', 'return'] },
    name: { type: 'string', description: '物品名称', maxLength: 80 },
    quantity: { type: 'number', description: '本次数量，大于零' },
    unit: { type: 'string', enum: ['个', '盒', '瓶', '包', '件', '其他'] },
    locationPath: { type: 'string', description: '存放位置' },
    expirationDate: { type: 'string', description: '用户明确提供的到期日期，格式 YYYY-MM-DD' },
    counterpart: { type: 'string', description: '借用人姓名' }
  }, required: ['action', 'name'] }
})
export default class ManageItemIntent extends InsightIntentEntryExecutor<string> {
  public action: string = '';
  public name: string = '';
  public quantity?: number;
  public unit?: string;
  public locationPath?: string;
  public expirationDate?: string;
  public counterpart?: string;

  async onExecute(): Promise<insightIntent.IntentResult<string>> {
    try {
      if (!(await AppServices.get().systemFeatures.get()).assistantEnabled) {
        return { code: -1, result: '请先在系统能力与隐私中开启小艺访问。' };
      }
      if (!['add', 'consume', 'borrow', 'return'].includes(this.action) || !this.name.trim() || this.name.length > 80) {
        return { code: -1, result: '请明确要操作的物品名称和操作类型。' };
      }
      ExternalRequestParser.publish({ action: this.action, name: this.name, quantity: this.quantity,
        unit: this.unit, locationPath: this.locationPath, expirationDate: this.expirationDate, counterpart: this.counterpart });
      return { code: 0, result: '已准备待确认内容，请在应用中核对并保存；目前尚未修改物品。' };
    } catch (_) { return { code: -1, result: '无法准备操作，请在应用中重试。' }; }
  }
}
