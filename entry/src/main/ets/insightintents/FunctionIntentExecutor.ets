import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ExternalRequestParser } from '../navigation/ExternalRequestParser';

export default class FunctionIntentExecutor extends InsightIntentExecutor {
  async onExecuteInUIAbilityForegroundMode(name: string, params: Record<string, Object>,
    stage: window.WindowStage): Promise<insightIntent.ExecuteResult> {
    if (name === 'ViewSearchPageLocal' && typeof params['query'] === 'string') {
      ExternalRequestParser.publish({ action: 'search', name: (params['query'] as string).slice(0, 100) });
      return { code: 0, result: { message: '已打开物品搜索' } };
    }
    const request = name === 'JumpFunctionPage' && typeof params['pageId'] === 'string' ?
      ExternalRequestParser.functionRequest(params['pageId'] as string) : undefined;
    if (request === undefined) { return { code: -1, result: { message: '不支持的功能入口' } }; }
    ExternalRequestParser.publish(request);
    return { code: 0, result: { message: '已打开功能' } };
  }
}
