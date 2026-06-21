export interface StockThreshold {
  itemId: string;
  threshold: number;
  enabled: boolean;
  updatedAt: number;
}

export interface LowStockItem {
  itemId: string;
  name: string;
  quantity: number;
  threshold: number;
}
