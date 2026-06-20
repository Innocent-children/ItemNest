import { relationalStore } from '@kit.ArkData';
import { AppError } from '../../common/AppError';
import { Result } from '../../common/Result';
import { Batch } from '../../model/Batch';
import { BATCH_TABLE } from '../rdb/BatchSchema';

export class BatchDao {
  constructor(private rdbStore: relationalStore.RdbStore) { }

  insert(batch: Batch): Result<void> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        id: batch.id,
        item_id: batch.itemId,
        quantity: batch.quantity,
        unit: batch.unit,
        expiration_date: batch.expirationDate,
        location_path: batch.locationPath,
        notes: batch.notes,
        created_at: batch.createdAt,
        updated_at: batch.updatedAt
      };
      this.rdbStore.insert(BATCH_TABLE, valueBucket);
      return Result.success();
    } catch (err) {
      return Result.failure(AppError.of('BATCH_INSERT', String(err)));
    }
  }

  getById(id: string): Result<Batch | null> {
    try {
      const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
      predicates.equalTo('id', id);
      const resultSet = this.rdbStore.query(predicates);
      if (resultSet.goToFirstRow()) {
        const batch = this.rowToBatch(resultSet);
        resultSet.close();
        return Result.success(batch);
      }
      resultSet.close();
      return Result.success(null);
    } catch (err) {
      return Result.failure(AppError.of('BATCH_GET', String(err)));
    }
  }

  listByItemId(itemId: string): Result<Batch[]> {
    try {
      const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
      predicates.equalTo('item_id', itemId);
      predicates.orderByAsc('created_at');
      const resultSet = this.rdbStore.query(predicates);
      const batches: Batch[] = [];
      while (resultSet.goToNextRow()) {
        batches.push(this.rowToBatch(resultSet));
      }
      resultSet.close();
      return Result.success(batches);
    } catch (err) {
      return Result.failure(AppError.of('BATCH_LIST', String(err)));
    }
  }

  update(batch: Batch): Result<void> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        quantity: batch.quantity,
        unit: batch.unit,
        expiration_date: batch.expirationDate,
        location_path: batch.locationPath,
        notes: batch.notes,
        updated_at: batch.updatedAt
      };
      const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
      predicates.equalTo('id', batch.id);
      const count = this.rdbStore.update(valueBucket, predicates);
      if (count === 0) {
        return Result.failure(AppError.of('BATCH_NOT_FOUND', '批次不存在'));
      }
      return Result.success();
    } catch (err) {
      return Result.failure(AppError.of('BATCH_UPDATE', String(err)));
    }
  }

  deleteById(id: string): Result<void> {
    try {
      const predicates = new relationalStore.RdbPredicates(BATCH_TABLE);
      predicates.equalTo('id', id);
      this.rdbStore.delete(predicates);
      return Result.success();
    } catch (err) {
      return Result.failure(AppError.of('BATCH_DELETE', String(err)));
    }
  }

  private rowToBatch(resultSet: relationalStore.ResultSet): Batch {
    return new Batch({
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      itemId: resultSet.getString(resultSet.getColumnIndex('item_id')),
      quantity: resultSet.getDouble(resultSet.getColumnIndex('quantity')),
      unit: resultSet.getString(resultSet.getColumnIndex('unit')),
      expirationDate: resultSet.getString(resultSet.getColumnIndex('expiration_date')),
      locationPath: resultSet.getString(resultSet.getColumnIndex('location_path')),
      notes: resultSet.getString(resultSet.getColumnIndex('notes')),
      createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
      updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
    });
  }
}
