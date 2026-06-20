export class SearchHistory {
  id: string = '';
  keyword: string = '';
  searchedAt: number = 0;
  constructor(init?: Partial<SearchHistory>) { Object.assign(this, init); }
}
