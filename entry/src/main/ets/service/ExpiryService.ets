import { ExpiryStatus } from '../model/ExpiryStatus';
import { Item } from '../model/Item';
import { StockStatus } from '../model/StockStatus';

const DAY_MILLIS: number = 24 * 60 * 60 * 1000;
const DEFAULT_REMINDER_DAYS: number = 7;

export class ExpiryService {
  getExpiryStatus(item: Item, now: Date = new Date()): ExpiryStatus {
    if (item.quantity <= 0 || item.expirationDate === undefined || item.expirationDate.length === 0) {
      return ExpiryStatus.NO_EXPIRY_DATE;
    }
    const expiration = this.toLocalDay(item.expirationDate);
    if (expiration === undefined) {
      return ExpiryStatus.NO_EXPIRY_DATE;
    }
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const daysUntilExpiration = Math.floor((expiration - today) / DAY_MILLIS);
    if (daysUntilExpiration < 0) {
      return ExpiryStatus.EXPIRED;
    }
    const effectiveReminderDays = item.reminderDays ?? DEFAULT_REMINDER_DAYS;
    return daysUntilExpiration <= effectiveReminderDays ? ExpiryStatus.DUE_SOON : ExpiryStatus.NORMAL;
  }

  getStockStatus(item: Item): StockStatus {
    return item.quantity === 0 ? StockStatus.OUT_OF_STOCK : StockStatus.AVAILABLE;
  }

  private toLocalDay(value: string): number | undefined {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
    if (match === null) {
      return undefined;
    }
    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    if (date.getFullYear() !== Number(match[1]) || date.getMonth() !== Number(match[2]) - 1 ||
      date.getDate() !== Number(match[3])) {
      return undefined;
    }
    return date.getTime();
  }
}
