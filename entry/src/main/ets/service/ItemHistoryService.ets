import { Result } from '../common/Result';
import { TraceEventRepositoryPort } from '../data/repository/TraceEventRepository';
import { TraceEvent, TraceEventType } from '../model/TraceEvent';

export class ItemHistoryService {
  private readonly repository: TraceEventRepositoryPort;
  constructor(repository: TraceEventRepositoryPort) { this.repository = repository; }

  async list(itemId: string): Promise<Result<TraceEvent[]>> {
    return this.repository.listByItemId(itemId);
  }
}

export function historyEventLabel(type: TraceEventType): string {
  switch (type) {
    case TraceEventType.CONSUME: return '用掉';
    case TraceEventType.STOCK_ADD: return '补入';
    case TraceEventType.MOVE: return '换位置';
    case TraceEventType.QUANTITY_ADJUST: return '数量调整为';
    case TraceEventType.BORROW: return '借出';
    case TraceEventType.RETURN: return '归还';
    case TraceEventType.IMPORT: return '导入';
    case TraceEventType.EXPORT: return '导出';
  }
}

export function historyTime(timestamp: number): string {
  const date = new Date(timestamp);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ` +
    `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}
