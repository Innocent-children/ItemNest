import { relationalStore } from '@kit.ArkData';
import { allocateLegacyReturns, ReturnAllocation, TraceEvent, TraceEventType } from '../../model/TraceEvent';
import { ResultSetReader } from './ResultSetReader';
import { SchemaExecutor } from './SchemaExecutor';

export const TRACE_EVENT_TABLE: string = 'trace_event';

const CREATE_TRACE_EVENT_TABLE: string = `
  CREATE TABLE IF NOT EXISTS trace_event (
    id TEXT PRIMARY KEY NOT NULL,
    item_id TEXT NOT NULL,
    batch_id TEXT,
    type TEXT NOT NULL,
    quantity REAL NOT NULL CHECK(quantity >= 0),
    counterpart TEXT,
    note TEXT,
    created_at INTEGER NOT NULL,
    voided_at INTEGER,
    return_allocations_json TEXT,
    legacy_allocated INTEGER NOT NULL DEFAULT 0
  )
`;

const TRACE_EVENT_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_trace_event_item_id ON trace_event(item_id)',
  'CREATE INDEX IF NOT EXISTS idx_trace_event_batch_id ON trace_event(batch_id)',
  'CREATE INDEX IF NOT EXISTS idx_trace_event_created_at ON trace_event(created_at DESC)'
];

export async function createTraceEventSchema(store: relationalStore.Transaction): Promise<void> {
  await SchemaExecutor.execute(store, CREATE_TRACE_EVENT_TABLE);
  for (let index = 0; index < TRACE_EVENT_INDEXES.length; index++) {
    await SchemaExecutor.execute(store, TRACE_EVENT_INDEXES[index]);
  }
}

/** Safe both during v12 upgrade and after restoring an older portable backup. */
export async function migrateLendingRelations(store: relationalStore.Transaction): Promise<void> {
  const columns: string[] = [];
  const tableInfo = await store.querySql('PRAGMA table_info(trace_event)');
  try {
    while (ResultSetReader.goToNextRow(tableInfo)) {
      columns.push(ResultSetReader.readString(tableInfo, 'name') ?? '');
    }
  } finally {
    ResultSetReader.close(tableInfo);
  }
  if (columns.indexOf('voided_at') < 0) {
    await SchemaExecutor.execute(store, 'ALTER TABLE trace_event ADD COLUMN voided_at INTEGER');
  }
  if (columns.indexOf('return_allocations_json') < 0) {
    await SchemaExecutor.execute(store, 'ALTER TABLE trace_event ADD COLUMN return_allocations_json TEXT');
  }
  if (columns.indexOf('legacy_allocated') < 0) {
    await SchemaExecutor.execute(store, 'ALTER TABLE trace_event ADD COLUMN legacy_allocated INTEGER NOT NULL DEFAULT 0');
  }

  const events: TraceEvent[] = [];
  const missingRelations: string[] = [];
  const rows = await store.querySql('SELECT * FROM trace_event ORDER BY created_at,id');
  try {
    while (ResultSetReader.goToNextRow(rows)) {
      const allocations = ResultSetReader.readString(rows, 'return_allocations_json');
      const event: TraceEvent = {
        id: ResultSetReader.readString(rows, 'id') ?? '',
        itemId: ResultSetReader.readString(rows, 'item_id') ?? '',
        batchId: ResultSetReader.readString(rows, 'batch_id'),
        type: (ResultSetReader.readString(rows, 'type') ?? TraceEventType.BORROW) as TraceEventType,
        quantity: ResultSetReader.readDouble(rows, 'quantity') ?? 0,
        counterpart: ResultSetReader.readString(rows, 'counterpart'),
        note: ResultSetReader.readString(rows, 'note'),
        createdAt: ResultSetReader.readLong(rows, 'created_at') ?? 0,
        voidedAt: ResultSetReader.readLong(rows, 'voided_at'),
        returnAllocations: allocations === undefined ? undefined : JSON.parse(allocations) as ReturnAllocation[],
        legacyAllocated: (ResultSetReader.readLong(rows, 'legacy_allocated') ?? 0) === 1 ? true : undefined
      };
      if (event.type === TraceEventType.RETURN && allocations === undefined && event.voidedAt === undefined) {
        missingRelations.push(event.id);
      }
      events.push(event);
    }
  } finally {
    ResultSetReader.close(rows);
  }
  allocateLegacyReturns(events);
  for (let index = 0; index < events.length; index++) {
    const event = events[index];
    if (missingRelations.indexOf(event.id) < 0) {
      continue;
    }
    const predicates = new relationalStore.RdbPredicates(TRACE_EVENT_TABLE);
    predicates.equalTo('id', event.id);
    await store.update({
      return_allocations_json: JSON.stringify(event.returnAllocations ?? []),
      legacy_allocated: 1
    }, predicates);
  }
}
