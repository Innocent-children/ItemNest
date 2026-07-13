import { relationalStore } from '@kit.ArkData';
import { SchemaExecutor } from './SchemaExecutor';

export const DATABASE_NAME: string = 'itemtrace.db';
export const DATABASE_VERSION: number = 10;
export const ITEM_TABLE: string = 'item';

const CREATE_ITEM_TABLE: string = `
  CREATE TABLE IF NOT EXISTS item (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 1 CHECK(quantity >= 0),
    unit TEXT NOT NULL DEFAULT '个',
    location_path TEXT,
    category TEXT,
    expiration_date TEXT,
    reminder_days INTEGER CHECK(reminder_days IS NULL OR (reminder_days >= 0 AND reminder_days <= 365)),
    notes TEXT,
    photo_state TEXT NOT NULL DEFAULT 'NONE',
    photo_local_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;

const ITEM_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_item_created_at ON item(created_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_item_location_path ON item(location_path)',
  'CREATE INDEX IF NOT EXISTS idx_item_category ON item(category)',
  'CREATE INDEX IF NOT EXISTS idx_item_expiration_date ON item(expiration_date)'
];

export async function createItemSchema(store: relationalStore.Transaction): Promise<void> {
  await SchemaExecutor.execute(store, CREATE_ITEM_TABLE);
  for (let index = 0; index < ITEM_INDEXES.length; index++) {
    await SchemaExecutor.execute(store, ITEM_INDEXES[index]);
  }
}
