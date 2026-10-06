import { describe, it, expect } from '@ohos/hypium';
import { CaptureDraftService } from '../../../main/ets/service/CaptureDraftService';
import { ExternalRequestParser } from '../../../main/ets/navigation/ExternalRequestParser';

export default function systemEntryTest() {
  describe('System entry and capture', () => {
    it('同一行的生产日期与到期日期分别识别', 0, () => {
      const result = new CaptureDraftService().parse('品名：牛奶\n生产日期：2026.10.06 保质期至：2026.10.13');
      expect(result.name).assertEqual('牛奶');
      expect(result.productionDate).assertEqual('2026-10-06');
      expect(result.expirationDate).assertEqual('2026-10-13');
    });
    it('没有明确标签的日期只作为候选', 0, () => {
      const result = new CaptureDraftService().parse('牛奶\n2026/10/06\n保质期：7天');
      expect(result.expirationDate).assertEqual('');
      expect(result.productionDate).assertEqual('');
      expect(result.dateCandidates[0]).assertEqual('2026-10-06');
      expect(result.shelfLife).assertEqual('7天');
    });
    it('拒绝不存在的日期并处理闰年', 0, () => {
      const service = new CaptureDraftService();
      expect(service.normalizeDate('2026-02-29')).assertEqual('');
      expect(service.normalizeDate('2028年2月29日')).assertEqual('2028-02-29');
      expect(service.normalizeDate('2026-13-01')).assertEqual('');
      expect(service.normalizeDate('2026-04-31')).assertEqual('');
    });
    it('生产日期后的下一行可以识别但不推算到期日', 0, () => {
      const result = new CaptureDraftService().parse('生产日期\n2026-10-06\n保质期：6个月');
      expect(result.productionDate).assertEqual('2026-10-06');
      expect(result.expirationDate).assertEqual('');
    });
    it('物品链接往返保留完整标识', 0, () => {
      const uri = ExternalRequestParser.itemUri('物品/1 #a');
      const request = ExternalRequestParser.parseUri(uri);
      expect(request?.action).assertEqual('item');
      expect(request?.itemId).assertEqual('物品/1 #a');
    });
    it('无效链接不能变成写入操作或任意页面', 0, () => {
      expect(ExternalRequestParser.parseUri('itemnest://function/delete')).assertUndefined();
      expect(ExternalRequestParser.parseUri('itemnest://item/%XX')).assertUndefined();
      expect(ExternalRequestParser.parseUri('itemnest://item/%00')).assertUndefined();
      expect(ExternalRequestParser.parseUri('https://example.com/item/1')).assertUndefined();
      expect(ExternalRequestParser.parseUri('itemnest://location/id?delete=true')).assertUndefined();
    });
    it('标签解析返回标识，不把标签内容当作位置路径', 0, () => {
      const request = ExternalRequestParser.parseUri('itemnest://location/token-1');
      expect(request?.locationId).assertEqual('token-1');
      expect(request?.locationPath).assertUndefined();
    });
  });
}
