import { relationalStore } from '@kit.ArkData';
import { SchemaExecutor } from './SchemaExecutor';

export const LOCATION_TABLE: string = 'managed_location';

const CREATE_LOCATION_TABLE: string = `
  CREATE TABLE IF NOT EXISTS managed_location (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    parent_id TEXT,
    path TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;

const LOCATION_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_managed_location_parent_id ON managed_location(parent_id)',
  'CREATE INDEX IF NOT EXISTS idx_managed_location_path ON managed_location(path)'
];

const MIGRATE_ITEM_LOCATIONS: string = `
  INSERT INTO managed_location (id, name, parent_id, path, active, created_at, updated_at)
  SELECT 'location-' || MIN(item.id),
         item.location_path,
         NULL,
         item.location_path,
         1,
         MIN(item.created_at),
         MAX(item.updated_at)
  FROM item
  WHERE item.location_path IS NOT NULL AND item.location_path <> ''
  GROUP BY item.location_path
`;

export async function createLocationSchema(store: relationalStore.Transaction): Promise<void> {
  await SchemaExecutor.execute(store, CREATE_LOCATION_TABLE);
  for (let index = 0; index < LOCATION_INDEXES.length; index++) {
    await SchemaExecutor.execute(store, LOCATION_INDEXES[index]);
  }
  await SchemaExecutor.execute(store, MIGRATE_ITEM_LOCATIONS);
}
