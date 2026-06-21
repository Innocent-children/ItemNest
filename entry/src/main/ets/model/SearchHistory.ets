import { Category } from './Category';

export interface SearchHistory {
  id: string;
  queryText?: string;
  locationPath?: string;
  category?: Category;
  viewedItemId?: string;
  createdAt: number;
}

export function createSearchHistoryId(clock: () => number = () => Date.now()): string {
  return `search-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
