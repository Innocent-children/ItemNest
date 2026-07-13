import { Result, success } from '../common/Result';
import { Item } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { createSearchHistoryId, SearchHistory } from '../model/SearchHistory';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { SearchHistoryRepositoryPort } from '../data/repository/SearchHistoryRepository';

export class SearchSuggestionResult {
  readonly suggestions: string[];
  readonly history: SearchHistory[];

  constructor(suggestions: string[], history: SearchHistory[]) {
    this.suggestions = suggestions;
    this.history = history;
  }
}

export class SearchSuggestionService {
  private readonly history: SearchHistoryRepositoryPort;
  private readonly items: ItemRepositoryPort;
  private readonly clock: () => number;

  constructor(history: SearchHistoryRepositoryPort, items: ItemRepositoryPort, clock: () => number = () => Date.now()) {
    this.history = history;
    this.items = items;
    this.clock = clock;
  }

  async getSuggestions(input: string): Promise<Result<SearchSuggestionResult>> {
    const historyResult = await this.history.recent(8);
    if (!historyResult.ok) {
      return success(new SearchSuggestionResult([], []));
    }
    const itemResult = await this.items.listAll();
    if (!itemResult.ok) {
      return success(new SearchSuggestionResult([], historyResult.getData()));
    }
    const normalized = input.trim();
    const suggestions: string[] = [];
    const items = itemResult.getData();
    for (let index = 0; index < items.length && suggestions.length < 8; index++) {
      const item = items[index];
      if (normalized.length === 0 || item.name.includes(normalized)) {
        this.pushUnique(suggestions, item.name);
      }
    }
    return success(new SearchSuggestionResult(suggestions, historyResult.getData()));
  }

  async recordSearch(query: ItemQuery): Promise<Result<SearchHistory>> {
    const normalized = query.normalized();
    return this.history.add({
      id: createSearchHistoryId(this.clock),
      queryText: normalized.name.length === 0 ? undefined : normalized.name,
      locationPath: normalized.locationPath,
      category: normalized.category,
      createdAt: this.clock()
    });
  }

  async recordViewedItem(item: Item): Promise<Result<SearchHistory>> {
    return this.history.add({
      id: createSearchHistoryId(this.clock),
      queryText: item.name,
      viewedItemId: item.id,
      createdAt: this.clock()
    });
  }

  async clearHistory(): Promise<Result<void>> {
    return this.history.clear();
  }

  private pushUnique(items: string[], value: string): void {
    if (items.indexOf(value) < 0) {
      items.push(value);
    }
  }
}
