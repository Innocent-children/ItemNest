import { relationalStore } from '@kit.ArkData';

export const BATCH_TABLE: string = 'batch';

const CREATE_BATCH_TABLE: string = `
  CREATE TABLE IF NOT EXISTS batch (
    id TEXT PRIMARY KEY NOT NULL,
    item_id TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 1,
    unit TEXT NOT NULL DEFAULT '个',
    expiration_date TEXT,
    location_path TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;

const MIGRATE_ITEM_TO_DEFAULT_BATCH: string = `
  INSERT INTO batch (id, item_id, quantity, unit, expiration_date, location_path, notes, created_at, updated_at)
  SELECT 'batch-' || item.id,
         item.id,
         item.quantity,
         item.unit,
         item.expiration_date,
         item.location_path,
         '默认批次',
         item.created_at,
         item.updated_at
  FROM item
  WHERE NOT EXISTS (
    SELECT 1 FROM batch WHERE batch.item_id = item.id
  )
`;

const BATCH_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_batch_item_id ON batch(item_id)',
  'CREATE INDEX IF NOT EXISTS idx_batch_expiration_date ON batch(expiration_date)'
];

export async function createBatchSchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_BATCH_TABLE);
  for (let index = 0; index < BATCH_INDEXES.length; index++) {
    await store.executeSql(BATCH_INDEXES[index]);
  }
  await store.executeSql(MIGRATE_ITEM_TO_DEFAULT_BATCH);
}
