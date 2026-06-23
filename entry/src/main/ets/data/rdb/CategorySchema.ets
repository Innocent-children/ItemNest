import { relationalStore } from '@kit.ArkData';
import { SchemaExecutor } from './SchemaExecutor';

export const CATEGORY_TABLE: string = 'managed_category';

const CREATE_CATEGORY_TABLE: string = `
  CREATE TABLE IF NOT EXISTS managed_category (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    system_preset INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
`;

const CATEGORY_INDEXES: string[] = [
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_managed_category_name ON managed_category(name)'
];

const SEED_PRESET_CATEGORIES: string = `
  INSERT OR IGNORE INTO managed_category (id, name, active, system_preset, created_at, updated_at)
  VALUES
    ('category-medicine', '药品', 1, 1, 0, 0),
    ('category-food', '食品', 1, 1, 0, 0),
    ('category-document', '证件', 1, 1, 0, 0),
    ('category-tool', '工具', 1, 1, 0, 0),
    ('category-office', '办公', 1, 1, 0, 0),
    ('category-daily', '生活用品', 1, 1, 0, 0),
    ('category-children', '儿童用品', 1, 1, 0, 0),
    ('category-pet', '宠物用品', 1, 1, 0, 0),
    ('category-other', '其他', 1, 1, 0, 0)
`;

const MIGRATE_ITEM_CATEGORIES: string = `
  INSERT OR IGNORE INTO managed_category (id, name, active, system_preset, created_at, updated_at)
  SELECT 'category-imported-' || item.category,
         item.category,
         1,
         0,
         MIN(item.created_at),
         MAX(item.updated_at)
  FROM item
  WHERE item.category IS NOT NULL AND item.category <> ''
  GROUP BY item.category
`;

export async function createCategorySchema(store: relationalStore.Transaction): Promise<void> {
  await SchemaExecutor.execute(store, CREATE_CATEGORY_TABLE);
  for (let index = 0; index < CATEGORY_INDEXES.length; index++) {
    await SchemaExecutor.execute(store, CATEGORY_INDEXES[index]);
  }
  await SchemaExecutor.execute(store, SEED_PRESET_CATEGORIES);
  await SchemaExecutor.execute(store, MIGRATE_ITEM_CATEGORIES);
}
