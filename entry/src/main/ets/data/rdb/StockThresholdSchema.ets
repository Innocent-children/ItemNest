import { relationalStore } from '@kit.ArkData';

export const STOCK_THRESHOLD_TABLE: string = 'stock_threshold';

const CREATE_STOCK_THRESHOLD_TABLE: string = `
  CREATE TABLE IF NOT EXISTS stock_threshold (
    item_id TEXT PRIMARY KEY NOT NULL,
    threshold REAL NOT NULL CHECK(threshold >= 0),
    enabled INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL
  )
`;

export async function createStockThresholdSchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_STOCK_THRESHOLD_TABLE);
}
