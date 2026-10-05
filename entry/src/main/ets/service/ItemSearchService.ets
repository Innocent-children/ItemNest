import { failure, Result, success } from '../common/Result';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { ItemListService } from './ItemListService';

export class SearchResult {
  readonly query: ItemQuery;
  readonly items: ItemSummary[];
  readonly hasNoResult: boolean;

  constructor(query: ItemQuery, items: ItemSummary[]) {
    this.query = query;
    this.items = items;
    this.hasNoResult = items.length === 0;
  }
}

export class FilterOptions {
  readonly locationPaths: string[];
  readonly categories: string[];

  constructor(locationPaths: string[], categories: string[]) {
    this.locationPaths = locationPaths;
    this.categories = categories;
  }
}

export class ItemSearchService {
  private readonly repository: ItemRepositoryPort;
  private readonly listService: ItemListService;

  constructor(repository: ItemRepositoryPort, listService: ItemListService) {
    this.repository = repository;
    this.listService = listService;
  }

  async search(query: ItemQuery, now: Date = new Date()): Promise<Result<SearchResult>> {
    const normalized = query.normalized();
    const itemsResult = await this.repository.list(normalized);
    if (!itemsResult.ok) {
      return failure<SearchResult>(itemsResult.getError());
    }
    const summaries: ItemSummary[] = [];
    const items = itemsResult.getData();
    for (let index = 0; index < items.length; index++) {
      summaries.push(this.listService.toSummary(items[index], now));
    }
    return success(new SearchResult(normalized, summaries));
  }

  async getFilterOptions(): Promise<Result<FilterOptions>> {
    const itemsResult = await this.repository.listAll();
    if (!itemsResult.ok) {
      return failure<FilterOptions>(itemsResult.getError());
    }
    const locationPaths: string[] = [];
    const categories: string[] = [];
    const items = itemsResult.getData();
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const paths = item.activeLocationPaths ?? (item.locationPath === undefined ? [] : [item.locationPath]);
      for (let pathIndex = 0; pathIndex < paths.length; pathIndex++) {
        const segments = paths[pathIndex].split('/').map((segment: string) => segment.trim());
        for (let depth = 1; depth <= segments.length; depth++) {
          const path = segments.slice(0, depth).join(' / ');
          if (path.length > 0 && locationPaths.indexOf(path) < 0) {
            locationPaths.push(path);
          }
        }
      }
      if (item.category !== undefined && categories.indexOf(item.category) < 0) {
        categories.push(item.category);
      }
    }
    return success(new FilterOptions(locationPaths, categories));
  }
}
