import { relationalStore } from '@kit.ArkData';

export const SEARCH_HISTORY_TABLE: string = 'search_history';

const CREATE_SEARCH_HISTORY_TABLE: string = `
  CREATE TABLE IF NOT EXISTS search_history (
    id TEXT PRIMARY KEY NOT NULL,
    query_text TEXT,
    location_path TEXT,
    category TEXT,
    viewed_item_id TEXT,
    created_at INTEGER NOT NULL
  )
`;

const SEARCH_HISTORY_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_search_history_created_at ON search_history(created_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_search_history_viewed_item_id ON search_history(viewed_item_id)'
];

export async function createSearchHistorySchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_SEARCH_HISTORY_TABLE);
  for (let index = 0; index < SEARCH_HISTORY_INDEXES.length; index++) {
    await store.executeSql(SEARCH_HISTORY_INDEXES[index]);
  }
}
