import { AppError } from '../common/AppError';
import { Result } from '../common/Result';

export class SearchSuggestionService {
  private history: string[] = [];
  private maxHistory: number = 20;

  record(keyword: string): void {
    if (keyword.trim().length === 0) return;
    this.history = this.history.filter(h => h !== keyword);
    this.history.unshift(keyword);
    if (this.history.length > this.maxHistory) {
      this.history = this.history.slice(0, this.maxHistory);
    }
  }

  getSuggestions(prefix: string): string[] {
    if (prefix.trim().length === 0) return this.history.slice(0, 10);
    const lower = prefix.toLowerCase();
    return this.history.filter(h => h.toLowerCase().includes(lower)).slice(0, 10);
  }

  clearHistory(): void {
    this.history = [];
  }

  getRecentHistory(): string[] {
    return [...this.history];
  }
}
