import { failure, Result, success } from '../common/Result';
import { ItemTraceExportPayload } from '../common/ImportValidation';
import { BatchRepositoryPort } from '../data/repository/BatchRepository';
import { CategoryRepository } from '../data/repository/CategoryRepository';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { LocationRepository } from '../data/repository/LocationRepository';
import { TraceEventRepository } from '../data/repository/TraceEventRepository';

export class ExportService {
  private readonly items: ItemRepositoryPort;
  private readonly batches: BatchRepositoryPort;
  private readonly locations: LocationRepository;
  private readonly categories: CategoryRepository;
  private readonly traces: TraceEventRepository;
  private readonly clock: () => number;

  constructor(items: ItemRepositoryPort, batches: BatchRepositoryPort, locations: LocationRepository,
    categories: CategoryRepository, traces: TraceEventRepository, clock: () => number = () => Date.now()) {
    this.items = items;
    this.batches = batches;
    this.locations = locations;
    this.categories = categories;
    this.traces = traces;
    this.clock = clock;
  }

  async exportJson(): Promise<Result<string>> {
    const items = await this.items.listAll();
    if (!items.ok) {
      return failure<string>(items.getError());
    }
    const batches = await this.batches.listAll();
    if (!batches.ok) {
      return failure<string>(batches.getError());
    }
    const locations = await this.locations.listAll();
    if (!locations.ok) {
      return failure<string>(locations.getError());
    }
    const categories = await this.categories.listAll();
    if (!categories.ok) {
      return failure<string>(categories.getError());
    }
    const traces = await this.traces.listAll();
    if (!traces.ok) {
      return failure<string>(traces.getError());
    }
    const payload: ItemTraceExportPayload = {
      version: 'itemtrace.phase3.v1',
      exportedAt: this.clock(),
      items: items.getData(),
      batches: batches.getData(),
      locations: locations.getData(),
      categories: categories.getData(),
      traceEvents: traces.getData()
    };
    return success(JSON.stringify(payload));
  }
}
