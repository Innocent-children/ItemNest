export class LatestRequestCoordinator {
  private latestRequestId: number = 0;

  begin(): number {
    return ++this.latestRequestId;
  }

  invalidate(): void {
    this.latestRequestId++;
  }

  isCurrent(requestId: number): boolean {
    return requestId === this.latestRequestId;
  }
}
