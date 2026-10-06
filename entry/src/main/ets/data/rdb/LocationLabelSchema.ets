import { relationalStore } from '@kit.ArkData';
import { SchemaExecutor } from './SchemaExecutor';

export async function createLocationLabelSchema(store: relationalStore.Transaction): Promise<void> {
  await SchemaExecutor.execute(store, 'CREATE TABLE IF NOT EXISTS location_label (' +
    'token TEXT PRIMARY KEY NOT NULL, location_id TEXT NOT NULL REFERENCES managed_location(id) ON DELETE CASCADE)');
  await SchemaExecutor.execute(store, 'CREATE INDEX IF NOT EXISTS idx_location_label_location ON location_label(location_id)');
}
