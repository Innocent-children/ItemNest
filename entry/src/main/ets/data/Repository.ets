import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Snapshot, Item, Location, Asset, Draft, ChangeEvent, Preference, copy, normalize, length, uuid, displayName, expiryDate, setDate, CATEGORY_CODES, statusText } from '../model/Models';
import { fileIo as fs } from '@kit.CoreFileKit';
import { i18n } from '@kit.LocalizationKit';

// 常见家用物品的叫法差异，用于搜索兜底；命中后排在名称和说明命中之后
const SYNONYMS: string[][] = [
  ['外套', '大衣', '羽绒服', '夹克', '风衣', '棉服'], ['充电器', '充电头', '适配器', '电源适配器'], ['数据线', '充电线', '线材'],
  ['证件', '护照', '身份证', '户口本', '驾驶证', '港澳通行证'], ['药', '药品', '药物', '药箱'], ['钥匙', '备用钥匙'],
  ['电池', '干电池', '纽扣电池', '充电电池'], ['伞', '雨伞', '雨具'], ['耳机', '耳麦'], ['票据', '发票', '保修卡', '说明书', '收据'],
  ['工具', '螺丝刀', '扳手', '锤子', '钳子'], ['被子', '被褥', '棉被', '床品'], ['鞋', '鞋子', '运动鞋', '靴子'], ['化妆品', '护肤品', '面霜', '口红']
];
let latinTransliterator: i18n.Transliterator | undefined = undefined;
let simplifiedTransliterator: i18n.Transliterator | undefined = undefined;
function latin(value: string): string {
  try {
    if (!latinTransliterator) latinTransliterator = i18n.Transliterator.getInstance('Han-Latin');
    return latinTransliterator.transform(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  } catch (_) { return ''; }
}
function simplified(value: string): string {
  try {
    if (!simplifiedTransliterator) simplifiedTransliterator = i18n.Transliterator.getInstance('Hant-Hans');
    return simplifiedTransliterator.transform(value);
  } catch (_) { return value; }
}
function hasHan(value: string): boolean { return /[\u4e00-\u9fff]/.test(value); }

class SearchDocument {
  names: string[] = [];
  nameText: string = '';
  tagText: string = '';
  fullText: string = '';
  pinyin: string = '';
  initials: string = '';
}
export class Repository {
  private store?: relationalStore.RdbStore;
  private context?: common.Context;
  private paths: Map<string, string> = new Map();
  private searchDocuments: Map<string, SearchDocument> = new Map();
  data: Snapshot = new Snapshot();
  onChange: () => void = () => {};

  async open(context: common.Context): Promise<void> {
    this.context = context;
    this.store = await relationalStore.getRdbStore(context, { name: 'itemnest_v1.db', securityLevel: relationalStore.SecurityLevel.S2 });
    await this.store.executeSql('CREATE TABLE IF NOT EXISTS entities (kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(kind,id))');
    await this.store.executeSql('CREATE TABLE IF NOT EXISTS operations (id TEXT PRIMARY KEY, result TEXT NOT NULL)');
    this.reload();
    if (!this.read<Preference>('preference').length) this.put('preference', this.data.preference.id, this.data.preference);
  }
  private db(): relationalStore.RdbStore { if (!this.store) throw new Error('数据正在读取，请稍后'); return this.store; }
  close(): void { this.store?.close(); this.store = undefined; }
  private read<T>(kind: string): T[] {
    const rows = this.db().querySqlSync('SELECT payload FROM entities WHERE kind=?', [kind]);
    const values: T[] = [];
    try { while (rows.goToNextRow()) values.push(JSON.parse(rows.getString(0)) as T); } finally { rows.close(); }
    return values;
  }
  private put<T>(kind: string, id: string, value: T): void {
    this.db().executeSync('INSERT OR REPLACE INTO entities(kind,id,payload) VALUES(?,?,?)', [kind, id, JSON.stringify(value)]);
  }
  private remove(kind: string, id: string): void { this.db().executeSync('DELETE FROM entities WHERE kind=? AND id=?', [kind, id]); }
  reload(): void {
    const data = new Snapshot();
    data.items = this.read<Item>('item'); data.locations = this.read<Location>('location'); data.assets = this.read<Asset>('asset');
    data.drafts = this.read<Draft>('draft').sort((a: Draft, b: Draft) => b.updatedAt - a.updatedAt);
    data.events = this.read<ChangeEvent>('event'); data.preference = this.read<Preference>('preference')[0] ?? this.data.preference;
    this.data = data; this.paths.clear(); this.searchDocuments.clear();
  }
  transaction(operation: () => void): void {
    const db = this.db(); db.beginTransaction();
    try { operation(); db.commit(); } catch (error) { db.rollBack(); throw error as Error; }
    this.reload(); this.onChange();
  }
  path(id: string, locations: Location[] = this.data.locations): string {
    const key = id; if (locations === this.data.locations && this.paths.has(id)) return this.paths.get(id)!;
    const names: string[] = []; const visited: string[] = [];
    while (id) {
      if (visited.includes(id)) throw new Error('位置关系存在循环'); visited.push(id);
      const node = locations.find((location: Location) => location.id === id);
      if (!node) break; names.unshift(node.name); id = node.parentId;
    }
    const result = names.join(' / '); if (locations === this.data.locations) this.paths.set(key, result); return result;
  }
  descendants(id: string, locations: Location[] = this.data.locations): string[] {
    const ids: string[] = [id];
    for (let i = 0; i < ids.length; i++) {
      locations.filter((location: Location) => location.parentId === ids[i]).forEach((location: Location) => {
        if (ids.includes(location.id)) throw new Error('位置关系存在循环'); ids.push(location.id);
      });
    }
    return ids;
  }
  validateLocations(locations: Location[]): void {
    const names: string[] = [];
    locations.forEach((location: Location) => {
      if (!location.name.trim() || length(location.name) > 30 || length(location.notes) > 500) throw new Error('位置名称为 1—30 字，备注最多 500 字');
      if (location.parentId && !locations.some((node: Location) => node.id === location.parentId)) throw new Error('父位置已变化，请重新选择');
      const key = location.parentId + ':' + normalize(location.name);
      if (names.includes(key)) throw new Error('这里已有这个位置，请改名或选择其他父位置'); names.push(key);
      let id = location.id; const visited: string[] = [];
      while (id) {
        if (visited.includes(id)) throw new Error('不能移动到自己或子位置中'); visited.push(id);
        if (visited.length > 4) throw new Error('移动后超过四层，请选择更上层的位置');
        id = locations.find((node: Location) => node.id === id)?.parentId ?? '';
      }
    });
  }
  saveLocation(input: Location): string {
    const current = this.data.locations.find((node: Location) => node.id === input.id);
    if (current && current.revision !== input.revision) throw new Error('位置已更新，请重新打开管理位置');
    const value = copy(input); value.name = value.name.trim(); value.normalizedName = normalize(value.name); value.revision++; value.updatedAt = Date.now();
    this.validateLocations([...this.data.locations.filter((node: Location) => node.id !== value.id), value]);
    this.transaction(() => this.put('location', value.id, value)); return value.id;
  }
  canReparent(id: string, parent: string): boolean {
    const subtree = this.descendants(id); if (subtree.includes(parent)) return false;
    const depth = (key: string): number => { let count = 0; while (key) { const node = this.data.locations.find((value: Location) => value.id === key); if (!node) break; count++; key = node.parentId; } return count; };
    const height = Math.max(1, ...subtree.map((key: string) => depth(key) - depth(id) + 1));
    return depth(parent) + height <= 4;
  }
  reorderLocation(id: string, offset: number): void {
    const current = this.data.locations.find((node: Location) => node.id === id); if (!current) return;
    const siblings = copy(this.data.locations.filter((node: Location) => node.parentId === current.parentId).sort((a: Location, b: Location) => a.sortOrder - b.sortOrder));
    const from = siblings.findIndex((node: Location) => node.id === id); const to = from + offset;
    if (to < 0 || to >= siblings.length) return;
    const moved = siblings.splice(from, 1)[0]; siblings.splice(to, 0, moved);
    this.transaction(() => siblings.forEach((node: Location, index: number) => { node.sortOrder = index; node.revision++; node.updatedAt = Date.now(); this.put('location', node.id, node); }));
  }
  deleteLocation(id: string, target: string): void {
    if (this.descendants(id).includes(target)) throw new Error('请选择此位置之外的安置位置');
    const children = this.data.locations.filter((node: Location) => node.parentId === id);
    const items = this.data.items.filter((item: Item) => item.locationId === id);
    if ((children.length || items.length) && !target) throw new Error('请先选择有效的安置位置');
    if (target && !this.data.locations.some((node: Location) => node.id === target)) throw new Error('安置位置已移除');
    const next = copy(this.data.locations.filter((node: Location) => node.id !== id));
    next.forEach((node: Location) => { if (node.parentId === id) { node.parentId = target; node.revision++; node.updatedAt = Date.now(); } });
    this.validateLocations(next);
    this.transaction(() => {
      next.forEach((node: Location) => this.put('location', node.id, node));
      items.forEach((old: Item) => { const item = copy(old); item.locationId = target; this.writeItem(item, old, '迁移位置', uuid()); });
      this.remove('location', id);
    });
  }
  validateItem(item: Item): void {
    item.title = item.title.trim(); item.notes = item.notes.trim();
    if (!['SINGLE','GROUP'].includes(item.kind) || !['ACTIVE','LENT','ARCHIVED'].includes(item.status) || !CATEGORY_CODES.includes(item.category)) throw new Error('记录类型、状态或分类无效');
    if (item.kind === 'GROUP') { item.quantity = null; if(item.archiveReason==='USED_UP') throw new Error('整组记录请选择送出、出售、丢弃或其他原因'); }
    const dedupe = (values: string[]): string[] => { const seen: string[] = []; return values.map((value:string)=>value.trim()).filter((value:string)=>{const key=normalize(value);if(!key || seen.includes(key))return false;seen.push(key);return true;}); };
    item.aliases=dedupe(item.aliases);item.tags=dedupe(item.tags);
    if (!item.title && !item.photoIds.length) throw new Error('写个名称，或加张照片');
    if (length(item.title) > 80 || length(item.notes) > 2000) throw new Error('名称最多 80 字，说明最多 2000 字');
    if (item.photoIds.length > 6 || item.photoIds.some((id: string) => !this.data.assets.some((asset: Asset) => asset.id === id))) throw new Error('请等待照片处理完成，每条最多 6 张');
    if (item.locationId && !this.data.locations.some((node: Location) => node.id === item.locationId)) throw new Error('位置已变化，请重新选择');
    if (item.kind === 'SINGLE' && (!Number.isInteger(item.quantity) || (item.quantity ?? 0) < (item.status === 'ARCHIVED' && item.archiveReason === 'USED_UP' ? 0 : 1) || (item.quantity ?? 0) > 9999)) throw new Error('单件数量为 1—9999 的整数');
    if (item.status === 'LENT' && (!item.borrower.trim() || length(item.borrower) > 40)) throw new Error('请填写对方称呼，最多 40 字');
    if (item.tags.length > 10 || item.tags.some((tag: string) => length(tag) > 20) || item.aliases.length > 5 || item.aliases.some((alias: string) => length(alias) > 30)) throw new Error('标签最多 10 个、每个 20 字；别名最多 5 个、每个 30 字');
    if (length(item.barcodeValue) > 256 || (!!item.barcodeValue !== !!item.barcodeType) || item.barcodeType && !['EAN13','EAN8','UPC_A','UPC_E','CODE128','QR'].includes(item.barcodeType)) throw new Error('请同时填写有效的条码类型与码值');
    setDate(item, 'EXPIRY', expiryDate(item.expiryInput));
    if (item.expiryInput.mode === 'DIRECT') { item.expiryInput.producedOn = ''; item.expiryInput.value = 0; }
    else item.expiryInput.directDate = '';
  }
  private writeItem(item: Item, before: Item | undefined, type: string, operation: string): void {
    item.revision = (before?.revision ?? 0) + 1; item.updatedAt = Date.now();
    if (item.locationId !== before?.locationId || type === '已归还') item.locationConfirmedAt = item.locationId ? Date.now() : 0;
    const event = new ChangeEvent(); event.itemId = item.id; event.type = type; event.operationId = operation;
    // 变化记录只保存发生变化的字段，每行一个“字段：值”，原来与现在按行对应
    const fields = (value: Item): string[] => [
      '名称：' + displayName(value), '状态：' + statusText(value), '位置：' + (this.path(value.locationId) || '位置待补充'),
      '日期：' + (value.dates.map((date) => (date.type === 'EXPIRY' ? '到期' : date.type === 'RETURN' ? '归还' : '保修') + ' ' + date.date + (date.handledAt ? ' 已处理' : '') + (date.remindEnabled ? '' : ' 不提醒')).join('；') || '无'),
      '说明：' + (value.notes || '无'), '标签：' + (value.tags.join('、') || '无'), '别名：' + (value.aliases.join('、') || '无'),
      '照片：' + value.photoIds.length + ' 张', '常用：' + (value.favorite ? '是' : '否')
    ];
    const now = fields(item);
    if (before) {
      const old = fields(before); const changed = now.map((_: string, index: number) => index).filter((index: number) => old[index] !== now[index]);
      event.before = changed.map((index: number) => old[index]).join('\n'); event.after = changed.map((index: number) => now[index]).join('\n');
    } else { event.before = ''; event.after = now.filter((line: string) => !line.endsWith('：无') && !line.endsWith('：0 张') && !line.endsWith('：否')).join('\n'); }
    this.put('item', item.id, item); this.put('event', event.id, event);
  }
  saveItem(input: Item, draftId: string = '', operationId: string = uuid(), force: boolean = false): string {
    const prior = this.db().querySqlSync('SELECT result FROM operations WHERE id=?', [operationId]);
    try { if (prior.goToFirstRow()) return prior.getString(0); } finally { prior.close(); }
    const item = copy(input); const before = this.data.items.find((value: Item) => value.id === item.id);
    if (before?.deletedAt) throw new Error('记录已移入回收站，请恢复后再编辑，或另存为新记录');
    if (!before && input.revision > 0) throw new Error('原记录已永久移除，可以另存为新记录');
    if (before && before.revision !== item.revision && !force) throw new Error('记录已有较新修改，请查看当前版本后再保存');
    this.validateItem(item);
    this.transaction(() => {
      this.writeItem(item, before, before ? '编辑物品' : '记下物品', operationId);
      if (draftId) this.remove('draft', draftId);
      this.db().executeSync('INSERT INTO operations(id,result) VALUES(?,?)', [operationId, item.id]);
    });
    if (item.locationId) { const pref = copy(this.data.preference); pref.recentLocations = [item.locationId, ...pref.recentLocations.filter((id: string) => id !== item.locationId)].slice(0, 3); this.savePreference(pref); }
    return item.id;
  }
  mutate(ids: string[], type: string, change: (item: Item) => void): void {
    const operation = uuid();
    const next = ids.map((id: string) => {
      const old = this.data.items.find((item: Item) => item.id === id); if (!old) throw new Error('记录已移除，请重新选择');
      const item = copy(old); change(item); this.validateItem(item); return item;
    });
    this.transaction(() => next.forEach((item: Item) => this.writeItem(item, this.data.items.find((old: Item) => old.id === item.id), type, operation)));
  }
  split(id: string, quantity: number, title: string, location: string, keepDates: boolean): string {
    const old = this.data.items.find((item: Item) => item.id === id);
    if (!old || old.kind !== 'SINGLE' || old.status !== 'ACTIVE' || old.deletedAt || !Number.isInteger(quantity) || quantity < 1 || quantity >= (old.quantity ?? 0)) throw new Error('拆出数量应为正整数，并小于当前在手数量');
    const left = copy(old); left.quantity = (left.quantity ?? 0) - quantity;
    const next = copy(old); next.id = uuid(); next.revision = 0; next.sourceItemId = old.id; next.quantity = quantity; next.title = title.trim(); next.locationId = location; next.createdAt = Date.now(); next.favorite = false;
    next.dates = keepDates ? copy(old.dates) : [];
    next.dates.forEach((date) => { date.id = uuid(); date.itemId = next.id; date.dateVersion = 1; date.handledAt = 0; });
    if (!keepDates) { next.expiryInput.directDate = ''; next.expiryInput.mode = 'DIRECT'; }
    this.validateItem(left); this.validateItem(next);
    this.transaction(() => { this.writeItem(left, old, '拆出数量', next.id); this.writeItem(next, undefined, '拆分记录', next.id); }); return next.id;
  }
  recycle(ids: string[]): void {
    this.mutate(ids, '移入回收站', (item: Item) => { item.deletedAt = Date.now(); item.purgeAt = item.deletedAt + 30 * 86400000; item.previousLocationPath = this.path(item.locationId); });
  }
  purge(ids: string[]): void {
    const candidates = this.data.items.filter((item: Item) => ids.includes(item.id)).flatMap((item: Item) => item.photoIds);
    this.transaction(() => ids.forEach((id: string) => {
      const item = this.data.items.find((value: Item) => value.id === id); if (!item?.deletedAt) throw new Error('只能永久删除回收站记录');
      this.remove('item', id); this.data.events.filter((event: ChangeEvent) => event.itemId === id).forEach((event: ChangeEvent) => this.remove('event', event.id));
      this.data.drafts.filter((draft: Draft) => draft.itemId === id).forEach((draft: Draft) => this.remove('draft', draft.id));
    }));
    this.releaseUnused(candidates);
  }
  unreferencedPhotoCount(id: string): number {
    const item = this.data.items.find((value: Item) => value.id === id); if (!item) return 0;
    return item.photoIds.filter((assetId: string) => !this.data.items.some((value: Item) => value.id !== id && value.photoIds.includes(assetId)) && !this.data.locations.some((node: Location) => node.photoAssetId === assetId) && !this.data.drafts.some((draft: Draft) => draft.itemId !== id && draft.assetIds.includes(assetId))).length;
  }
  private releaseUnused(candidates: string[]): void {
    const context = this.context; if (!context || !candidates.length) return;
    const used = new Set<string>();
    this.data.items.forEach((item: Item) => item.photoIds.forEach((id: string) => used.add(id)));
    this.data.locations.forEach((node: Location) => { if (node.photoAssetId) used.add(node.photoAssetId); });
    this.data.drafts.forEach((draft: Draft) => draft.assetIds.forEach((id: string) => used.add(id)));
    const removable = this.data.assets.filter((asset: Asset) => candidates.includes(asset.id) && !used.has(asset.id));
    removable.forEach((asset: Asset) => {
      const path = context.filesDir + '/' + asset.relativePath;
      try { if (fs.accessSync(path)) fs.unlinkSync(path); const thumbnail = context.cacheDir + '/' + asset.id + '.jpg'; if (fs.accessSync(thumbnail)) fs.unlinkSync(thumbnail); this.remove('asset', asset.id); } catch (_) {}
    });
    this.reload();
  }
  saveDraft(input: Draft): void { const draft = copy(input); draft.assetIds = [...draft.payload.photoIds, ...(draft.sharedItems ?? []).flatMap((item: Item) => item.photoIds)]; draft.updatedAt = Date.now(); this.put('draft', draft.id, draft); this.reload(); }
  saveShared(draft: Draft, items: Item[]): string[] {
    if (!items.length || items.length > 9) throw new Error('请选择 1—9 张有效图片');
    const operation = draft.sessionId;
    const prior = this.db().querySqlSync('SELECT result FROM operations WHERE id=?', [operation]);
    try { if (prior.goToFirstRow()) return JSON.parse(prior.getString(0)) as string[]; } finally { prior.close(); }
    items.forEach((item: Item) => this.validateItem(item));
    const ids = items.map((item: Item) => item.id);
    this.transaction(() => {
      items.forEach((item: Item) => this.writeItem(copy(item), undefined, '从分享记下', operation));
      this.remove('draft', draft.id);
      this.db().executeSync('INSERT INTO operations(id,result) VALUES(?,?)', [operation, JSON.stringify(ids)]);
    });
    return ids;
  }
  deleteDraft(id: string): void { this.transaction(() => this.remove('draft', id)); }
  maintain(context: common.Context): void {
    const expired=this.data.items.filter((item:Item)=>item.deletedAt && item.purgeAt<=Date.now()).map((item:Item)=>item.id);
    if(expired.length)this.purge(expired);
    // 清理旧版本误存的空草稿：新建草稿里既没有名称、照片，也没有任何填写内容
    const empty=this.data.drafts.filter((draft:Draft)=>{const item=draft.payload;return draft.mode==='CREATE' && !item.title.trim() && !item.photoIds.length && !draft.assetIds.length && !item.notes.trim() && !item.expiryInput.directDate && !item.expiryInput.producedOn && !item.expiryInput.value && !item.aliases.length && !item.tags.length && !item.category && !item.barcodeValue && !item.dates.length && !draft.candidates;}).map((draft:Draft)=>draft.id);
    if(empty.length){this.transaction(()=>empty.forEach((id:string)=>this.remove('draft',id)));this.data.drafts=this.data.drafts.filter((draft:Draft)=>!empty.includes(draft.id));}
    const refs=new Set<string>();
    this.data.items.forEach((item:Item)=>item.photoIds.forEach((id:string)=>refs.add(id)));
    this.data.locations.forEach((node:Location)=>{if(node.photoAssetId)refs.add(node.photoAssetId);});
    this.data.drafts.forEach((draft:Draft)=>{[...draft.assetIds,...draft.payload.photoIds,...(draft.sharedItems??[]).flatMap((item:Item)=>item.photoIds)].forEach((id:string)=>refs.add(id));});
    // 新导入图片可能尚在编辑器中，保留一天缓冲；保护快照已自带独立照片副本。
    const orphaned=this.data.assets.filter((asset:Asset)=>!refs.has(asset.id) && asset.createdAt<Date.now()-86400000);
    if(orphaned.length)this.transaction(()=>orphaned.forEach((asset:Asset)=>this.remove('asset',asset.id)));
    orphaned.forEach((asset:Asset)=>{const path=context.filesDir+'/'+asset.relativePath;try{if(fs.accessSync(path))fs.unlinkSync(path);const thumb=context.cacheDir+'/'+asset.id+'.jpg';if(fs.accessSync(thumb))fs.unlinkSync(thumb);}catch(_){} });
    const protection=context.filesDir+'/protection.json';
    if(fs.accessSync(protection)){const info=JSON.parse(fs.readTextSync(protection)) as Record<string,number>;if(info.expiresAt<Date.now()){const archive=context.filesDir+'/protection.zip';if(fs.accessSync(archive))fs.unlinkSync(archive);fs.unlinkSync(protection);}}
  }
  addAsset(asset: Asset): void { this.put('asset', asset.id, asset); this.reload(); }
  savePreference(pref: Preference): void { this.put('preference', pref.id, pref); this.reload(); this.onChange(); }
  viewed(id: string): void { const old = this.data.items.find((item: Item) => item.id === id); if (!old) return; const item = copy(old); item.lastViewedAt = Date.now(); this.put('item', id, item); this.reload(); }
  private document(item: Item): SearchDocument {
    const existing = this.searchDocuments.get(item.id); if (existing) return existing;
    const document = new SearchDocument(); document.names = [item.title, ...item.aliases].map((value: string) => normalize(value));
    document.nameText = normalize([displayName(item), ...item.aliases].join(' '));
    document.tagText = normalize(document.nameText + ' ' + item.tags.join(' '));
    document.fullText = normalize([document.tagText, item.notes, this.path(item.locationId)].join(' '));
    // 名称、别名和位置的拼音，支持 huzhao、hz 这样的输入
    const spoken = [item.title, ...item.aliases, this.path(item.locationId)].filter((value: string) => hasHan(value)).map((value: string) => latin(value));
    document.pinyin = spoken.map((value: string) => value.replace(/[^a-z0-9]/g, '')).join(' ');
    document.initials = spoken.map((value: string) => value.split(/[^a-z0-9]+/).filter((part: string) => !!part).map((part: string) => part[0]).join('')).join(' ');
    this.searchDocuments.set(item.id, document); return document;
  }
  private fuzzy(document: SearchDocument, word: string): boolean {
    if (/^[a-z0-9]+$/.test(word) && /[a-z]/.test(word) && (document.pinyin.includes(word) || document.initials.includes(word))) return true;
    const group = SYNONYMS.find((values: string[]) => values.some((value: string) => value === word || (word.length >= 2 && value.includes(word))));
    return !!group && group.some((value: string) => document.fullText.includes(value));
  }
  search(query: string, scope: string = 'CURRENT', filter: string = '', category: string = '', location: string = '', children: boolean = true): Item[] {
    const text = Array.from(normalize(hasHan(query) ? simplified(query) : query)).slice(0, 100).join(''); const words = text.split(' ').filter((word: string) => !!word).slice(0, 10);
    const allowed = location ? (children ? this.descendants(location) : [location]) : [];
    const rank = (item: Item): number => {
      const document = this.document(item);
      if (document.names.includes(text)) return 0;
      if (words.every((word: string) => document.nameText.includes(word))) return 1;
      if (words.every((word: string) => document.tagText.includes(word))) return 2;
      if (words.every((word: string) => document.fullText.includes(word))) return 3;
      return 4;
    };
    return this.data.items.filter((item: Item) => {
      if (scope === 'TRASH' ? !item.deletedAt : item.deletedAt || (scope === 'ARCHIVED' ? item.status !== 'ARCHIVED' : item.status === 'ARCHIVED')) return false;
      if (filter === '常用' && !item.favorite || filter === '借出' && item.status !== 'LENT' || filter === '整组' && item.kind !== 'GROUP') return false;
      if (category && item.category !== category || location && !allowed.includes(item.locationId)) return false;
      return !words.length || words.every((word: string) => this.document(item).fullText.includes(word) || this.fuzzy(this.document(item), word));
    }).sort((a: Item, b: Item) => (text ? rank(a) - rank(b) : 0) || b.updatedAt - a.updatedAt || a.id.localeCompare(b.id));
  }
  replaceSnapshot(snapshot: Snapshot): void {
    this.validateLocations(snapshot.locations);
    this.transaction(() => {
      this.db().executeSync('DELETE FROM entities');
      this.db().executeSync('DELETE FROM operations');
      snapshot.items.forEach((value: Item) => this.put('item', value.id, value));
      snapshot.locations.forEach((value: Location) => this.put('location', value.id, value));
      snapshot.assets.forEach((value: Asset) => this.put('asset', value.id, value));
      snapshot.drafts.forEach((value: Draft) => this.put('draft', value.id, value));
      snapshot.events.forEach((value: ChangeEvent) => this.put('event', value.id, value));
      this.put('preference', 'preferences', snapshot.preference);
    });
  }
}
