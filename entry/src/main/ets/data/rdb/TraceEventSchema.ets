import { relationalStore } from '@kit.ArkData';

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
    created_at INTEGER NOT NULL
  )
`;

const TRACE_EVENT_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_trace_event_item_id ON trace_event(item_id)',
  'CREATE INDEX IF NOT EXISTS idx_trace_event_batch_id ON trace_event(batch_id)',
  'CREATE INDEX IF NOT EXISTS idx_trace_event_created_at ON trace_event(created_at DESC)'
];

export async function createTraceEventSchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_TRACE_EVENT_TABLE);
  for (let index = 0; index < TRACE_EVENT_INDEXES.length; index++) {
    await store.executeSql(TRACE_EVENT_INDEXES[index]);
  }
}
