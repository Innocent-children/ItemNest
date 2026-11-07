import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';

export function uuid(): string { return util.generateRandomUUID(); }
export function normalize(value: string): string { return value.normalize('NFKC').toLowerCase().trim().replace(/\s+/g, ' '); }
export function copy<T>(value: T): T { return JSON.parse(JSON.stringify(value)) as T; }
export function length(value: string): number { return Array.from(value).length; }
export const CATEGORY_CODES: string[] = ['', 'DIGITAL', 'CLOTHING', 'HOME', 'FOOD', 'TOOLS', 'DOCUMENTS', 'OTHER'];
export const CATEGORY_NAMES: string[] = ['添加分类', '数码', '衣物', '家居', '食品', '工具', '证件', '其他'];

export class ExpiryInput {
  mode: string = 'DIRECT';
  directDate: string = '';
  producedOn: string = '';
  value: number = 0;
  unit: string = 'MONTH';
}
export class ItemDate {
  id: string = uuid();
  itemId: string = '';
  type: string = 'EXPIRY';
  date: string = '';
  remindEnabled: boolean = true;
  dateVersion: number = 1;
  handledAt: number = 0;
  createdAt: number = Date.now();
  updatedAt: number = Date.now();
}
export class Item {
  id: string = uuid();
  revision: number = 0;
  kind: string = 'SINGLE';
  title: string = '';
  aliases: string[] = [];
  notes: string = '';
  category: string = '';
  tags: string[] = [];
  locationId: string = '';
  quantity: number | null = 1;
  status: string = 'ACTIVE';
  borrower: string = '';
  lentAt: number = 0;
  archiveReason: string = '';
  archivedAt: number = 0;
  favorite: boolean = false;
  locationConfirmedAt: number = 0;
  createdAt: number = Date.now();
  updatedAt: number = Date.now();
  lastViewedAt: number = 0;
  deletedAt: number = 0;
  purgeAt: number = 0;
  previousLocationPath: string = '';
  sourceItemId: string = '';
  expiryInput: ExpiryInput = new ExpiryInput();
  barcodeType: string = '';
  barcodeValue: string = '';
  photoIds: string[] = [];
  missingPhotoCount: number = 0;
  dates: ItemDate[] = [];
}
export class Location {
  id: string = uuid();
  revision: number = 0;
  createdAt: number = Date.now();
  updatedAt: number = Date.now();
  parentId: string = '';
  name: string = '';
  normalizedName: string = '';
  photoAssetId: string = '';
  notes: string = '';
  sortOrder: number = Date.now();
}
export class Asset {
  id: string = uuid();
  sha256: string = '';
  relativePath: string = '';
  mime: string = 'image/jpeg';
  width: number = 0;
  height: number = 0;
  byteSize: number = 0;
  createdAt: number = Date.now();
}
export class Draft {
  id: string = uuid();
  mode: string = 'CREATE';
  itemId: string = '';
  baseRevision: number = 0;
  sessionId: string = uuid();
  payload: Item = new Item();
  assetIds: string[] = [];
  updatedAt: number = Date.now();
  candidates: string = '';
  sharedItems: Item[] = [];
  shareAsGroup: boolean = false;
  shareSourceCount: number = 0;
}
// 编辑是否有变化取决于表单字段；查看时间和日期对象的内部修订都可能独立变化。
export function editorContent(item: Item): string {
  const expiry = item.expiryInput;
  const warranty = item.dates.find((date: ItemDate) => date.type === 'WARRANTY');
  const dueReturn = item.dates.find((date: ItemDate) => date.type === 'RETURN');
  return JSON.stringify([item.title, item.kind, item.notes, item.category, item.aliases, item.tags,
    item.locationId, item.quantity, item.photoIds, item.barcodeType, item.barcodeValue,
    expiry.mode, expiry.directDate, expiry.producedOn, expiry.value, expiry.unit,
    warranty?.date ?? '', dueReturn?.date ?? '']);
}
export class ChangeEvent {
  id: string = uuid();
  itemId: string = '';
  operationId: string = '';
  type: string = '';
  before: string = '';
  after: string = '';
  createdAt: number = Date.now();
}
export class Preference {
  id: string = 'preferences';
  theme: string = 'SYSTEM';
  motion: string = 'SYSTEM';
  cardSummary: boolean = false;
  cardIds: string[] = [];
  cardMode: string = 'COMMON';
  reminderEnabled: boolean = false;
  externalDetails: boolean = false;
  recentLocations: string[] = [];
  searchHistory: string[] = [];
  lastBackupAt: number = 0;
  datasetId: string = uuid();
  lastTab: number = 0;
}
export class Snapshot {
  schemaVersion: number = 1;
  items: Item[] = [];
  locations: Location[] = [];
  assets: Asset[] = [];
  drafts: Draft[] = [];
  events: ChangeEvent[] = [];
  preference: Preference = new Preference();
}
export function displayName(item: Item): string {
  if (item.title) return item.title;
  if (!item.photoIds.length) return '未命名记录';
  const date = new Date(item.createdAt);
  return `照片记录 · ${date.getMonth() + 1}月${date.getDate()}日 ${clockTime(item.createdAt)}`;
}
export function daysUntil(value: string): number {
  if (!validDate(value)) return 0;
  const target = new Date(value + 'T12:00:00').getTime();
  const today = new Date(localDate() + 'T12:00:00').getTime();
  return Math.round((target - today) / 86400000);
}
export function shortDate(value: string): string {
  if (!validDate(value)) return value;
  const parts = value.split('-').map((part: string) => Number(part));
  return (parts[0] === new Date().getFullYear() ? '' : parts[0] + '年') + parts[1] + '月' + parts[2] + '日';
}
export function dateTypeName(type: string): string { return type === 'RETURN' ? '归还' : type === 'WARRANTY' ? '保修' : '到期'; }
export function relativeDue(value: string, type: string = 'EXPIRY'): string {
  const days = daysUntil(value);
  const verb = type === 'RETURN' ? '归还' : type === 'WARRANTY' ? '保修到期' : '到期';
  if (days < 0) return type === 'RETURN' ? `已超过归还日 ${-days} 天` : type === 'WARRANTY' ? `保修已过期 ${-days} 天` : `已过期 ${-days} 天`;
  if (days === 0) return '今天' + verb;
  if (days === 1) return '明天' + verb;
  if (days === 2) return '后天' + verb;
  if (days <= 60) return `${days} 天后${verb}`;
  return shortDate(value) + verb;
}
export function uses24Hour(): boolean { try { return i18n.System.is24HourClock(); } catch (_) { return true; } }
export function clockTime(time: number): string {
  const date = new Date(time); const hour = date.getHours(); const minute = String(date.getMinutes()).padStart(2, '0');
  if (uses24Hour()) return `${String(hour).padStart(2, '0')}:${minute}`;
  const period = hour < 6 ? '凌晨' : hour < 12 ? '上午' : hour < 13 ? '中午' : hour < 18 ? '下午' : '晚上';
  return `${period}${hour % 12 || 12}:${minute}`;
}
export function reminderClock(): string { const date = new Date(); date.setHours(9, 0, 0, 0); return clockTime(date.getTime()); }
export function friendlyTime(time: number): string {
  if (!time) return '';
  const day = localDate(new Date(time)); const yesterday = new Date(); yesterday.setDate(yesterday.getDate() - 1);
  const prefix = day === localDate() ? '今天' : day === localDate(yesterday) ? '昨天' : shortDate(day);
  return prefix + ' ' + clockTime(time);
}
export function firstGlyph(item: Item): string { const text = Array.from(item.title.trim()); return text.length ? text[0].toUpperCase() : (item.kind === 'GROUP' ? '组' : '物'); }
export function statusText(item: Item): string {
  if (item.deletedAt) return '回收站';
  if (item.status === 'LENT') return `借给${item.borrower} · ${item.kind === 'GROUP' ? '整组记录' : item.quantity + ' 件'}`;
  if (item.status === 'ARCHIVED') {
    const reason = ['USED_UP','GIVEN','SOLD','DISCARDED','OTHER'].indexOf(item.archiveReason);
    return (['已用完','已送出','已出售','已丢弃','已归档'][reason] ?? '已归档') + (item.kind === 'GROUP' ? ' · 整组记录' : ` · ${item.quantity} 件`);
  }
  return item.kind === 'GROUP' ? '整组记录' : `在手 · ${item.quantity} 件`;
}
export function localDate(date: Date = new Date()): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
export function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(value + 'T12:00:00');
  return Number.isFinite(date.getTime()) && localDate(date) === value && value >= '1900-01-01' && value <= '2200-12-31';
}
export function expiryDate(input: ExpiryInput): string {
  if (!['DIRECT', 'SHELF_LIFE'].includes(input.mode) || !['DAY', 'MONTH', 'YEAR'].includes(input.unit)) throw new Error('日期填法或保质期单位无效');
  if (input.mode === 'DIRECT') {
    if (input.directDate && !validDate(input.directDate)) throw new Error('请填写有效的到期日期（1900—2200 年）');
    return input.directDate;
  }
  if (!Number.isInteger(input.value) || input.value < 1 || input.value > (input.unit === 'DAY' ? 36500 : input.unit === 'YEAR' ? 100 : 1200)) {
    throw new Error('请填写有效的整数保质期');
  }
  if (!input.producedOn) return '';
  if (!validDate(input.producedOn)) throw new Error('请填写有效的生产日期');
  const date = new Date(input.producedOn + 'T12:00:00');
  if (input.unit === 'DAY') date.setDate(date.getDate() + input.value);
  else {
    const day = date.getDate();
    date.setDate(1);
    date.setMonth(date.getMonth() + input.value * (input.unit === 'YEAR' ? 12 : 1));
    const last = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    date.setDate(Math.min(day, last));
  }
  const result = localDate(date);
  if (!validDate(result)) throw new Error('计算结果超出 1900—2200 年范围');
  return result;
}
export function setDate(item: Item, type: string, value: string): void {
  if (value && !validDate(value)) throw new Error('请填写有效日期，格式为 YYYY-MM-DD');
  const old = item.dates.find((date: ItemDate) => date.type === type);
  if (!value) { item.dates = item.dates.filter((date: ItemDate) => date.type !== type); return; }
  if (old) {
    if (old.date !== value) { old.date = value; old.dateVersion++; old.handledAt = 0; old.updatedAt = Date.now(); }
  } else {
    const date = new ItemDate(); date.itemId = item.id; date.type = type; date.date = value; item.dates.push(date);
  }
}
