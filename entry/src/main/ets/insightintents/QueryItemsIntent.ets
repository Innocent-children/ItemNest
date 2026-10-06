import { InsightIntentEntry, InsightIntentEntryExecutor, insightIntent } from '@kit.AbilityKit';
import { AppServices } from '../service/AppServices';
import { ItemQuery } from '../model/ItemQuery';

@InsightIntentEntry({
  intentName: 'QueryStoredItems', domain: 'ToolsDomain', intentVersion: '1.0.0',
  displayName: '查询我的物品', displayDescription: '查询物品的存放位置、库存、临期和借出待还信息',
  llmDescription: '查询 我的家当 已记录的物品。kind 为 items 查询名称位置库存，expiry 查询临期，loans 查询借出待还。只查询，不修改记录。',
  keywords: ['物品在哪', '还有多少', '即将过期', '借出待还'], abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: { type: 'object', properties: {
    name: { type: 'string', description: '物品名称，可为空', maxLength: 80 },
    kind: { type: 'string', enum: ['items', 'expiry', 'loans'], description: '查询类型' }
  }, required: ['kind'] }
})
export default class QueryItemsIntent extends InsightIntentEntryExecutor<string> {
  public name: string = '';
  public kind: string = 'items';

  async onExecute(): Promise<insightIntent.IntentResult<string>> {
    try {
      const services = AppServices.get();
      if (!(await services.systemFeatures.get()).assistantEnabled) {
        return { code: -1, result: '请先在 我的家当 的系统能力与隐私中开启小艺访问。' };
      }
      if (this.kind === 'expiry') {
        const result = await services.homeSummary.getSummary();
        if (!result.ok) { throw result.getError(); }
        const items = result.getData().expiryAttentionItems.filter(item => this.name.length === 0 || item.name.includes(this.name));
        return { code: 0, result: items.length === 0 ? '没有符合条件的临期物品。' :
          '共有 ' + items.length + ' 件到期待处理物品。' + items.slice(0, 10).map(item => item.name + '：' + item.expirationDate).join('；') };
      }
      if (this.kind === 'loans') {
        const result = await services.lending.getOutstandingLoans();
        if (!result.ok) { throw result.getError(); }
        const loans = result.getData().filter(item => this.name.length === 0 || item.itemName.includes(this.name));
        return { code: 0, result: loans.length === 0 ? '没有符合条件的借出待还记录。' :
          '共有 ' + loans.length + ' 条借出待还记录。' + loans.slice(0, 10).map(item => item.itemName + '，借给' +
            (item.loan.borrowEvent.counterpart || '未记录姓名的人') + '，尚欠 ' + item.loan.remainingQuantity + item.unit).join('；') };
      }
      if (this.kind !== 'items' || this.name.length > 80) { return { code: -1, result: '查询参数无效。' }; }
      const result = await services.searchItems.search(new ItemQuery(this.name));
      if (!result.ok) { throw result.getError(); }
      const lines: string[] = [];
      for (const item of result.getData().items.slice(0, 10)) {
        const state = await services.lending.getState(item.id);
        if (!state.ok) { throw state.getError(); }
        lines.push(item.name + '，总量 ' + item.quantity + item.unit + '，可用 ' + state.getData().availableQuantity + item.unit +
          '，记录位置：' + (item.activeLocationPaths?.join('、') || item.locationPath || '未填写'));
      }
      return { code: 0, result: lines.length === 0 ? '没有找到已记录的物品。' :
        '找到 ' + result.getData().items.length + ' 件物品。' + lines.join('；') };
    } catch (_) { return { code: -1, result: '暂时无法读取物品，请打开 我的家当 重试。' }; }
  }
}
