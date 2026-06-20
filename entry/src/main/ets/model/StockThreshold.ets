export class StockThreshold {
  id: string = '';
  itemId: string | null = null;
  category: string | null = null;
  minQuantity: number = 1;
  enabled: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;

  constructor(init?: Partial<StockThreshold>) {
    Object.assign(this, init);
  }
}
