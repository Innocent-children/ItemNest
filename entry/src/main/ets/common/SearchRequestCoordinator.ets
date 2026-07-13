export class SearchRequestCoordinator {
  private searchRequestId: number = 0;
  private suggestionRequestId: number = 0;
  private refreshRequestId: number = 0;
  private filterOptionsRequestId: number = 0;

  beginSearch(): number {
    this.refreshRequestId++;
    return ++this.searchRequestId;
  }

  beginSuggestion(): number {
    return ++this.suggestionRequestId;
  }

  beginRefresh(): number {
    this.searchRequestId++;
    return ++this.refreshRequestId;
  }

  beginFilterOptions(): number {
    return ++this.filterOptionsRequestId;
  }

  invalidateSearchResults(): void {
    this.searchRequestId++;
    this.refreshRequestId++;
  }

  invalidateSuggestions(): void {
    this.suggestionRequestId++;
  }

  invalidateQueryRequests(): void {
    this.invalidateSearchResults();
    this.invalidateSuggestions();
  }

  isCurrentSearch(requestId: number): boolean {
    return requestId === this.searchRequestId;
  }

  isCurrentSuggestion(requestId: number): boolean {
    return requestId === this.suggestionRequestId;
  }

  isCurrentRefresh(requestId: number): boolean {
    return requestId === this.refreshRequestId;
  }

  isCurrentFilterOptions(requestId: number): boolean {
    return requestId === this.filterOptionsRequestId;
  }
}
