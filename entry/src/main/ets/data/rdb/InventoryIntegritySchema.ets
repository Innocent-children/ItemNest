import { relationalStore } from '@kit.ArkData';
import { SchemaExecutor } from './SchemaExecutor';

const BACKFILL_ITEMS_WITHOUT_BATCHES: string = `
  INSERT INTO batch (id, item_id, quantity, unit, expiration_date, location_path, notes, created_at, updated_at)
  SELECT 'batch-default-' || item.id,
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

const REPAIR_ITEM_ROLLUPS: string = `
  UPDATE item
  SET quantity = ROUND(COALESCE((
        SELECT SUM(batch.quantity) FROM batch WHERE batch.item_id = item.id
      ), 0), 2),
      expiration_date = (
        SELECT MIN(batch.expiration_date)
        FROM batch
        WHERE batch.item_id = item.id
          AND batch.expiration_date IS NOT NULL
          AND batch.expiration_date <> ''
      )
  WHERE EXISTS (
    SELECT 1 FROM batch WHERE batch.item_id = item.id
  )
`;

const CREATE_ITEM_DEFAULT_BATCH_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_after_insert_default_batch
  AFTER INSERT ON item
  BEGIN
    INSERT INTO batch (id, item_id, quantity, unit, expiration_date, location_path, notes, created_at, updated_at)
    VALUES ('batch-default-' || NEW.id,
            NEW.id,
            NEW.quantity,
            NEW.unit,
            NEW.expiration_date,
            NEW.location_path,
            '默认批次',
            NEW.created_at,
            NEW.updated_at);
  END
`;

const CREATE_BATCH_INSERT_GUARD_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_before_insert_validate_parent
  BEFORE INSERT ON batch
  BEGIN
    SELECT RAISE(ABORT, 'batch item missing')
    WHERE NOT EXISTS (SELECT 1 FROM item WHERE item.id = NEW.item_id);
    SELECT RAISE(ABORT, 'batch unit mismatch')
    WHERE NEW.unit <> (SELECT item.unit FROM item WHERE item.id = NEW.item_id);
  END
`;

const CREATE_BATCH_UPDATE_GUARD_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_before_update_validate_parent
  BEFORE UPDATE OF item_id, unit ON batch
  BEGIN
    SELECT RAISE(ABORT, 'batch item missing')
    WHERE NOT EXISTS (SELECT 1 FROM item WHERE item.id = NEW.item_id);
    SELECT RAISE(ABORT, 'batch unit mismatch')
    WHERE NEW.unit <> (SELECT item.unit FROM item WHERE item.id = NEW.item_id);
  END
`;

const CREATE_BATCH_INSERT_ROLLUP_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_after_insert_rollup_item
  AFTER INSERT ON batch
  BEGIN
    UPDATE item
    SET quantity = ROUND(COALESCE((
          SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = NEW.item_id
        ), 0), 2),
        expiration_date = (
          SELECT MIN(current_batch.expiration_date)
          FROM batch current_batch
          WHERE current_batch.item_id = NEW.item_id
            AND current_batch.expiration_date IS NOT NULL
            AND current_batch.expiration_date <> ''
        ),
        updated_at = CASE WHEN NEW.updated_at > updated_at THEN NEW.updated_at ELSE updated_at END
    WHERE id = NEW.item_id;
  END
`;

const CREATE_BATCH_UPDATE_ROLLUP_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_after_update_rollup_item
  AFTER UPDATE ON batch
  BEGIN
    UPDATE item
    SET quantity = ROUND(COALESCE((
          SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = OLD.item_id
        ), 0), 2),
        expiration_date = (
          SELECT MIN(current_batch.expiration_date)
          FROM batch current_batch
          WHERE current_batch.item_id = OLD.item_id
            AND current_batch.expiration_date IS NOT NULL
            AND current_batch.expiration_date <> ''
        ),
        updated_at = CASE WHEN NEW.updated_at > updated_at THEN NEW.updated_at ELSE updated_at END
    WHERE id = OLD.item_id;

    UPDATE item
    SET quantity = ROUND(COALESCE((
          SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = NEW.item_id
        ), 0), 2),
        expiration_date = (
          SELECT MIN(current_batch.expiration_date)
          FROM batch current_batch
          WHERE current_batch.item_id = NEW.item_id
            AND current_batch.expiration_date IS NOT NULL
            AND current_batch.expiration_date <> ''
        ),
        updated_at = CASE WHEN NEW.updated_at > updated_at THEN NEW.updated_at ELSE updated_at END
    WHERE id = NEW.item_id AND NEW.item_id <> OLD.item_id;
  END
`;

const CREATE_BATCH_TRACE_CLEANUP_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_before_delete_clear_trace_reference
  BEFORE DELETE ON batch
  BEGIN
    UPDATE trace_event SET batch_id = NULL WHERE batch_id = OLD.id;
  END
`;

const CREATE_BATCH_DELETE_ROLLUP_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_after_delete_rollup_item
  AFTER DELETE ON batch
  BEGIN
    UPDATE item
    SET quantity = ROUND(COALESCE((
          SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = OLD.item_id
        ), 0), 2),
        expiration_date = (
          SELECT MIN(current_batch.expiration_date)
          FROM batch current_batch
          WHERE current_batch.item_id = OLD.item_id
            AND current_batch.expiration_date IS NOT NULL
            AND current_batch.expiration_date <> ''
        ),
        updated_at = CASE
          WHEN CAST(strftime('%s', 'now') AS INTEGER) * 1000 > updated_at
            THEN CAST(strftime('%s', 'now') AS INTEGER) * 1000
          ELSE updated_at + 1
        END
    WHERE id = OLD.item_id;
  END
`;

const CREATE_ITEM_ROLLUP_GUARD_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_after_update_preserve_batch_rollup
  AFTER UPDATE OF quantity, expiration_date ON item
  WHEN EXISTS (SELECT 1 FROM batch WHERE batch.item_id = NEW.id)
    AND (
      ABS(NEW.quantity - ROUND(COALESCE((
        SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = NEW.id
      ), 0), 2)) > 0.000000001
      OR NEW.expiration_date IS NOT (
        SELECT MIN(current_batch.expiration_date)
        FROM batch current_batch
        WHERE current_batch.item_id = NEW.id
          AND current_batch.expiration_date IS NOT NULL
          AND current_batch.expiration_date <> ''
      )
    )
  BEGIN
    UPDATE item
    SET quantity = ROUND(COALESCE((
          SELECT SUM(current_batch.quantity) FROM batch current_batch WHERE current_batch.item_id = NEW.id
        ), 0), 2),
        expiration_date = (
          SELECT MIN(current_batch.expiration_date)
          FROM batch current_batch
          WHERE current_batch.item_id = NEW.id
            AND current_batch.expiration_date IS NOT NULL
            AND current_batch.expiration_date <> ''
        )
    WHERE id = NEW.id;
  END
`;

const CREATE_ITEM_UNIT_GUARD_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_before_update_preserve_batch_unit
  BEFORE UPDATE OF unit ON item
  WHEN NEW.unit <> OLD.unit
    AND EXISTS (SELECT 1 FROM batch WHERE batch.item_id = NEW.id)
  BEGIN
    SELECT RAISE(ABORT, 'item unit managed by batches');
  END
`;

const CREATE_ITEM_DELETE_CLEANUP_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_after_delete_cleanup_relations
  AFTER DELETE ON item
  BEGIN
    DELETE FROM batch WHERE item_id = OLD.id;
    DELETE FROM stock_threshold WHERE item_id = OLD.id;
    DELETE FROM trace_event WHERE item_id = OLD.id;
    DELETE FROM search_history WHERE viewed_item_id = OLD.id;
    DELETE FROM reminder_record WHERE item_id = OLD.id;
    DELETE FROM item_asset WHERE item_id = OLD.id;
  END
`;

export const INVENTORY_V10_TRIGGER_NAMES: string[] = [
  'trg_item_after_insert_default_batch',
  'trg_batch_before_insert_validate_parent',
  'trg_batch_before_update_validate_parent',
  'trg_batch_after_insert_rollup_item',
  'trg_batch_after_update_rollup_item',
  'trg_batch_before_delete_clear_trace_reference',
  'trg_batch_after_delete_rollup_item',
  'trg_item_after_update_preserve_batch_rollup',
  'trg_item_before_update_preserve_batch_unit',
  'trg_item_after_delete_cleanup_relations'
];

export const INVENTORY_V10_MIGRATION_STATEMENTS: string[] = [
  BACKFILL_ITEMS_WITHOUT_BATCHES,
  REPAIR_ITEM_ROLLUPS,
  CREATE_ITEM_DEFAULT_BATCH_TRIGGER,
  CREATE_BATCH_INSERT_GUARD_TRIGGER,
  CREATE_BATCH_UPDATE_GUARD_TRIGGER,
  CREATE_BATCH_INSERT_ROLLUP_TRIGGER,
  CREATE_BATCH_UPDATE_ROLLUP_TRIGGER,
  CREATE_BATCH_TRACE_CLEANUP_TRIGGER,
  CREATE_BATCH_DELETE_ROLLUP_TRIGGER,
  CREATE_ITEM_ROLLUP_GUARD_TRIGGER,
  CREATE_ITEM_UNIT_GUARD_TRIGGER,
  CREATE_ITEM_DELETE_CLEANUP_TRIGGER
];

export async function createInventoryIntegritySchema(store: relationalStore.Transaction): Promise<void> {
  for (let index = 0; index < INVENTORY_V10_MIGRATION_STATEMENTS.length; index++) {
    await SchemaExecutor.execute(store, INVENTORY_V10_MIGRATION_STATEMENTS[index]);
  }
}

export function inventoryOutstandingSql(itemExpression: string): string {
  return `ROUND(COALESCE((
    SELECT SUM(MAX(0, borrowed.quantity - COALESCE((
      SELECT SUM(CAST(json_extract(allocation.value, '$.quantity') AS REAL))
      FROM trace_event returned, json_each(returned.return_allocations_json) allocation
      WHERE returned.item_id = borrowed.item_id AND returned.type = 'RETURN' AND returned.voided_at IS NULL
        AND json_extract(allocation.value, '$.borrowEventId') = borrowed.id
    ), 0)))
    FROM trace_event borrowed
    WHERE borrowed.item_id = ${itemExpression} AND borrowed.type = 'BORROW' AND borrowed.voided_at IS NULL
  ), 0), 2)`;
}

const CREATE_ITEM_UNIT_SYNC_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_after_update_sync_batch_unit
  AFTER UPDATE OF unit ON item
  WHEN NEW.unit <> OLD.unit
  BEGIN
    UPDATE batch SET unit = NEW.unit,
      updated_at = CASE WHEN NEW.updated_at > updated_at THEN NEW.updated_at ELSE updated_at END
    WHERE item_id = NEW.id;
  END
`;

const CREATE_ITEM_STOCK_GUARD_TRIGGER: string = `
  CREATE TRIGGER IF NOT EXISTS trg_item_before_update_preserve_outstanding_stock
  BEFORE UPDATE OF quantity ON item
  WHEN NEW.quantity < OLD.quantity - 0.000000001
    AND NEW.quantity < (${inventoryOutstandingSql('NEW.id')}) - 0.000000001
  BEGIN
    SELECT RAISE(ABORT, 'inventory quantity below outstanding loans');
  END
`;

const CREATE_BATCH_QUANTITY_INSERT_GUARD: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_before_insert_validate_quantity
  BEFORE INSERT ON batch
  WHEN NEW.quantity < 0 OR ABS(NEW.quantity * 100 - ROUND(NEW.quantity * 100)) >= 0.000000001
  BEGIN
    SELECT RAISE(ABORT, 'invalid batch quantity');
  END
`;

const CREATE_BATCH_QUANTITY_UPDATE_GUARD: string = `
  CREATE TRIGGER IF NOT EXISTS trg_batch_before_update_validate_quantity
  BEFORE UPDATE OF quantity ON batch
  WHEN NEW.quantity < 0 OR ABS(NEW.quantity * 100 - ROUND(NEW.quantity * 100)) >= 0.000000001
  BEGIN
    SELECT RAISE(ABORT, 'invalid batch quantity');
  END
`;

function withActiveExpiration(sql: string): string {
  return sql.split('AND batch.expiration_date IS NOT NULL')
    .join('AND batch.quantity > 0 AND batch.expiration_date IS NOT NULL')
    .split('AND current_batch.expiration_date IS NOT NULL')
    .join('AND current_batch.quantity > 0 AND current_batch.expiration_date IS NOT NULL');
}

export const INVENTORY_V12_MIGRATION_STATEMENTS: string[] = [
  ...INVENTORY_V10_TRIGGER_NAMES.map((name: string) => `DROP TRIGGER IF EXISTS ${name}`),
  withActiveExpiration(REPAIR_ITEM_ROLLUPS),
  CREATE_ITEM_DEFAULT_BATCH_TRIGGER,
  CREATE_BATCH_INSERT_GUARD_TRIGGER,
  CREATE_BATCH_UPDATE_GUARD_TRIGGER,
  withActiveExpiration(CREATE_BATCH_INSERT_ROLLUP_TRIGGER),
  withActiveExpiration(CREATE_BATCH_UPDATE_ROLLUP_TRIGGER),
  CREATE_BATCH_TRACE_CLEANUP_TRIGGER,
  withActiveExpiration(CREATE_BATCH_DELETE_ROLLUP_TRIGGER),
  withActiveExpiration(CREATE_ITEM_ROLLUP_GUARD_TRIGGER),
  CREATE_ITEM_DELETE_CLEANUP_TRIGGER,
  CREATE_ITEM_UNIT_SYNC_TRIGGER,
  CREATE_ITEM_STOCK_GUARD_TRIGGER,
  CREATE_BATCH_QUANTITY_INSERT_GUARD,
  CREATE_BATCH_QUANTITY_UPDATE_GUARD
];

export async function updateInventoryIntegritySchema(store: relationalStore.Transaction): Promise<void> {
  for (let index = 0; index < INVENTORY_V12_MIGRATION_STATEMENTS.length; index++) {
    await SchemaExecutor.execute(store, INVENTORY_V12_MIGRATION_STATEMENTS[index]);
  }
}
