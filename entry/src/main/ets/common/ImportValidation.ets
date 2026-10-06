import { AppError, AppErrorCode } from './AppError';
import { failure, Result, success } from './Result';
import { Batch } from '../model/Batch';
import { CategoryRecord } from '../model/Category';
import { Item } from '../model/Item';
import { LocationRecord } from '../model/Location';
import { TraceEvent } from '../model/TraceEvent';

export interface ItemTraceExportPayload {
  version: string;
  exportedAt: number;
  items: Item[];
  batches: Batch[];
  locations: LocationRecord[];
  categories: CategoryRecord[];
  traceEvents: TraceEvent[];
}

export class ImportPreview {
  readonly itemCount: number;
  readonly batchCount: number;
  readonly locationCount: number;
  readonly categoryCount: number;
  readonly traceEventCount: number;
  readonly exportedAt?: number;
  readonly photoCount: number;
  readonly thresholdCount: number;
  readonly locationLabelCount: number;
  readonly sampleNames: string[];

  constructor(itemCount: number, batchCount: number, locationCount: number, categoryCount: number,
    traceEventCount: number, exportedAt?: number, photoCount: number = 0, thresholdCount: number = 0,
    sampleNames: string[] = [], locationLabelCount: number = 0) {
    this.locationLabelCount = locationLabelCount;
    this.itemCount = itemCount;
    this.batchCount = batchCount;
    this.locationCount = locationCount;
    this.categoryCount = categoryCount;
    this.traceEventCount = traceEventCount;
    this.exportedAt = exportedAt;
    this.photoCount = photoCount;
    this.thresholdCount = thresholdCount;
    this.sampleNames = sampleNames.slice(0, 5);
  }
}

export class ImportValidation {
  validate(text: string): Result<ItemTraceExportPayload> {
    try {
      const payload = JSON.parse(text) as ItemTraceExportPayload;
      if (payload.version !== 'itemtrace.phase3.v1') {
        return failure<ItemTraceExportPayload>(new AppError(AppErrorCode.VALIDATION, '导入文件版本不受支持'));
      }
      if (!Array.isArray(payload.items) || !Array.isArray(payload.batches) ||
        !Array.isArray(payload.locations) || !Array.isArray(payload.categories) || !Array.isArray(payload.traceEvents)) {
        return failure<ItemTraceExportPayload>(new AppError(AppErrorCode.VALIDATION, '导入文件结构不完整'));
      }
      return success(payload);
    } catch (_) {
      return failure<ItemTraceExportPayload>(new AppError(AppErrorCode.VALIDATION, '导入文件不是有效 JSON'));
    }
  }

  preview(payload: ItemTraceExportPayload): ImportPreview {
    return new ImportPreview(payload.items.length, payload.batches.length, payload.locations.length,
      payload.categories.length, payload.traceEvents.length, payload.exportedAt, 0, 0,
      payload.items.slice(0, 5).map((item: Item) => item.name));
  }
}
