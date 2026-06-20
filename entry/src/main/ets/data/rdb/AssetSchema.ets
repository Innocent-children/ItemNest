import { relationalStore } from '@kit.ArkData';

export const ASSET_TABLE: string = 'item_asset';

const CREATE_ASSET_TABLE: string = `
  CREATE TABLE IF NOT EXISTS item_asset (
    id TEXT PRIMARY KEY NOT NULL,
    item_id TEXT NOT NULL,
    local_path TEXT NOT NULL,
    source TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )
`;

const ASSET_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_item_asset_item_id ON item_asset(item_id)',
  'CREATE INDEX IF NOT EXISTS idx_item_asset_created_at ON item_asset(created_at DESC)'
];

export async function createAssetSchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_ASSET_TABLE);
  for (let index = 0; index < ASSET_INDEXES.length; index++) {
    await store.executeSql(ASSET_INDEXES[index]);
  }
}
