import { relationalStore } from '@kit.ArkData';

export const REMINDER_TABLE: string = 'reminder_record';

const CREATE_REMINDER_TABLE: string = `
  CREATE TABLE IF NOT EXISTS reminder_record (
    item_id TEXT PRIMARY KEY NOT NULL,
    scheduled_at INTEGER,
    system_reminder_id INTEGER,
    status TEXT NOT NULL,
    error_summary TEXT,
    updated_at INTEGER NOT NULL
  )
`;

const REMINDER_INDEXES: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_reminder_record_status ON reminder_record(status)',
  'CREATE INDEX IF NOT EXISTS idx_reminder_record_scheduled_at ON reminder_record(scheduled_at)'
];

export async function createReminderSchema(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(CREATE_REMINDER_TABLE);
  for (let index = 0; index < REMINDER_INDEXES.length; index++) {
    await store.executeSql(REMINDER_INDEXES[index]);
  }
}
