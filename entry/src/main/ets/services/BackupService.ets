import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker, hash, statfs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { Repository } from '../data/Repository';
import { Snapshot, Item, Location, Asset, Draft, ItemDate, ChangeEvent, Preference, copy, uuid, normalize, displayName, validDate, expiryDate, length, CATEGORY_CODES, statusText } from '../model/Models';

class Envelope<T> { schemaVersion: number = 1; records: T[] = []; }
class ItemPhoto { itemId: string = ''; assetId: string = ''; order: number = 0; }
class FileEntry { path: string = ''; byteSize: number = 0; sha256: string = ''; }
class Counts { single: number = 0; group: number = 0; archived: number = 0; trash: number = 0; locations: number = 0; drafts: number = 0; photos: number = 0; }
class Manifest {
  format: string = 'itemnest'; formatVersion: number = 1; schemaVersion: number = 1; appVersion: string = '1.0.0'; exportedAt: number = Date.now(); datasetId: string = ''; counts: Counts = new Counts(); files: FileEntry[] = []; assets: Asset[] = [];
}
export class RestoreConflict {
  id: string = ''; kind: string = ''; title: string = ''; current: string = ''; backup: string = ''; useBackup: boolean = false; targetId:string='';
}
export class RestorePreview {
  directory: string = ''; manifest: Manifest = new Manifest(); snapshot: Snapshot = new Snapshot(); conflicts: RestoreConflict[] = []; newItems: number = 0; existingItems: number = 0; expired: number = 0; warnings:string[]=[]; requiredBytes: number = 0;
}
export class BackupService {
  private context: common.Context;
  private repository: Repository;
  private temporary: string[] = [];
  cancelled: boolean = false;
  progress: (message: string) => void = () => {};
  constructor(context: common.Context, repository: Repository) { this.context = context; this.repository = repository; }
  cleanup(): void {
    this.temporary.forEach((path: string) => { try { if (fs.accessSync(path)) { if (fs.statSync(path).isDirectory()) fs.rmdirSync(path); else fs.unlinkSync(path); } } catch (_) {} });
    this.temporary = [];
  }
  private check(): void { if (this.cancelled) throw new Error('已取消，当前家当保持不变'); }
  private write(path: string, text: string): void { const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC); try { fs.writeSync(file.fd, text); fs.fsyncSync(file.fd); } finally { fs.closeSync(file); } }
  private async copyFile(from: string, to: string): Promise<void> { const source = await fs.open(from, fs.OpenMode.READ_ONLY); try { await fs.copyFile(source.fd, to); } finally { await fs.close(source); } }
  private counts(data: Snapshot): Counts { const result = new Counts(); result.single = data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'SINGLE').length; result.group = data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'GROUP').length; result.archived = data.items.filter((item: Item) => !item.deletedAt && item.status === 'ARCHIVED').length; result.trash = data.items.filter((item: Item) => !!item.deletedAt).length; result.locations = data.locations.length; result.drafts = data.drafts.length; result.photos = data.assets.length; return result; }
  private async recordFile(root: string, path: string, manifest: Manifest): Promise<void> { const entry = new FileEntry(); entry.path = path; entry.byteSize = fs.statSync(root + '/' + path).size; entry.sha256 = await hash.hash(root + '/' + path, 'sha256'); manifest.files.push(entry); }
  private async table<T>(root: string, name: string, records: T[], manifest: Manifest): Promise<void> { const envelope = new Envelope<T>(); envelope.records = records; const path = 'data/' + name + '.json'; this.write(root + '/' + path, JSON.stringify(envelope)); await this.recordFile(root, path, manifest); }
  async archive(snapshot: Snapshot, destination: string): Promise<void> {
    snapshot = copy(snapshot);
    const references = new Set<string>();
    snapshot.items.forEach((item: Item) => item.photoIds.forEach((id: string) => references.add(id)));
    snapshot.locations.forEach((node: Location) => { if (node.photoAssetId) references.add(node.photoAssetId); });
    snapshot.drafts.forEach((draft: Draft) => [...draft.payload.photoIds, ...(draft.sharedItems ?? []).flatMap((item: Item) => item.photoIds)].forEach((id: string) => references.add(id)));
    snapshot.assets = snapshot.assets.filter((asset: Asset) => references.has(asset.id));
    this.check(); const root = this.context.cacheDir + '/backup-' + uuid(); fs.mkdirSync(root); fs.mkdirSync(root + '/data'); fs.mkdirSync(root + '/assets');
    const manifest = new Manifest(); manifest.datasetId = snapshot.preference.datasetId; manifest.counts = this.counts(snapshot); manifest.assets = snapshot.assets;
    const photos: ItemPhoto[] = []; const dates: ItemDate[] = [];
    const items = copy(snapshot.items);
    items.forEach((item: Item) => { item.photoIds.forEach((id: string, index: number) => { const photo = new ItemPhoto(); photo.itemId = item.id; photo.assetId = id; photo.order = index; photos.push(photo); }); dates.push(...item.dates); item.photoIds = []; item.dates = []; });
    try {
      this.progress('正在保存数据快照');
      await this.table(root, 'locations', snapshot.locations, manifest); await this.table(root, 'items', items, manifest); await this.table(root, 'item-photos', photos, manifest); await this.table(root, 'item-dates', dates, manifest); await this.table(root, 'change-events', snapshot.events, manifest); await this.table(root, 'drafts', snapshot.drafts, manifest); await this.table(root, 'preferences', [snapshot.preference], manifest);
      for (let index = 0; index < snapshot.assets.length; index++) { this.check(); const asset = snapshot.assets[index]; this.progress(`正在打包照片 ${index + 1}/${snapshot.assets.length}`); await this.copyFile(this.context.filesDir + '/' + asset.relativePath, root + '/' + asset.relativePath); await this.recordFile(root, asset.relativePath, manifest); }
      this.write(root + '/manifest.json', JSON.stringify(manifest)); this.check(); this.progress('正在生成完整备份');
      await zlib.compressFile(root, destination, { keepTopLevelFolder: false });
      this.check();
    } finally { if (fs.accessSync(root)) fs.rmdirSync(root); }
  }
  async exportBackup(): Promise<string> {
    this.cancelled = false; const snapshot = copy(this.repository.data); const zip = this.context.cacheDir + '/export-' + uuid() + '.zip'; this.temporary.push(zip);
    await this.archive(snapshot, zip);
    const date=new Date();const name='我的家当_'+date.getFullYear()+String(date.getMonth()+1).padStart(2,'0')+String(date.getDate()).padStart(2,'0')+'_'+String(date.getHours()).padStart(2,'0')+String(date.getMinutes()).padStart(2,'0')+String(date.getSeconds()).padStart(2,'0')+'.itemnest';
    this.check(); const destinations = await new picker.DocumentViewPicker(this.context as common.UIAbilityContext).save({ newFileNames: [name] });
    if (!destinations.length) return '已取消保存，自己的家当保持不变';
    this.check(); await this.copyToUri(zip, destinations[0]);
    const preference = copy(this.repository.data.preference); preference.lastBackupAt = Date.now(); this.repository.savePreference(preference);
    const size = fs.statSync(zip).size; fs.unlinkSync(zip); return `已保存 ${name}（${Math.ceil(size / 1024)} KB）\n${destinations[0]}`;
  }
  private async copyToUri(path: string, uri: string): Promise<void> { const file = await fs.open(uri, fs.OpenMode.READ_WRITE); try { await fs.copyFile(path, file.fd); } finally { await fs.close(file); } }
  async exportProtection(): Promise<string> {
    const path = this.context.filesDir + '/protection.zip';
    if (!fs.accessSync(path)) throw new Error('还没有替换保护快照');
    const destinations = await new picker.DocumentViewPicker(this.context as common.UIAbilityContext).save({ newFileNames: ['我的家当_替换前保护快照.itemnest'] });
    if (!destinations.length) return '已取消';
    await this.copyToUri(path, destinations[0]); return '保护快照已另存为完整备份';
  }
  async exportText(name: string, text: string): Promise<string> { const result = await new picker.DocumentViewPicker(this.context as common.UIAbilityContext).save({ newFileNames: [name] }); if (!result.length) return '已取消'; const file = await fs.open(result[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC); try { await fs.write(file.fd, text); } finally { await fs.close(file); } return '已保存到 ' + result[0]; }
  async exportCsv(includeArchived: boolean): Promise<string> {
    const cell = (value: string): string => { const safe = /^[=+\-@\t\r\n]/.test(value) ? "'" + value : value; return '"' + safe.replace(/"/g, '""') + '"'; };
    const rows: string[][] = [['记录 ID','名称','记录类型','数量','状态','位置','分类','标签','备注','借出称呼','到期日期','保修日期','归还日期','更新时间','日期填法','生产日期','保质期数值','保质期单位','条码类型','商品条码']];
    this.repository.data.items.filter((item: Item) => !item.deletedAt && (includeArchived || item.status !== 'ARCHIVED')).forEach((item: Item) => rows.push([item.id,item.title,item.kind,item.kind === 'GROUP' ? '' : String(item.quantity),item.status,this.repository.path(item.locationId),item.category,item.tags.join('、'),item.notes,item.borrower,...['EXPIRY','WARRANTY','RETURN'].map((type: string) => item.dates.find((date: ItemDate) => date.type === type)?.date ?? ''),new Date(item.updatedAt).toISOString(),item.expiryInput.mode,item.expiryInput.producedOn,String(item.expiryInput.value || ''),item.expiryInput.unit,item.barcodeType,item.barcodeValue]));
    return this.exportText('我的家当清单.csv', '\ufeff' + rows.map((row: string[]) => row.map(cell).join(',')).join('\r\n'));
  }
  private readAt(fd: number, offset: number, size: number): ArrayBuffer { const buffer = new ArrayBuffer(size); fs.lseek(fd, offset, fs.WhenceType.SEEK_SET); if (fs.readSync(fd, buffer) !== size) throw new Error('备份文件读取不完整'); return buffer; }
  /**
   * 解压前核对中央目录和本地文件名，拒绝绝对路径、父目录、链接及超限资源。
   */
  private inspectZip(path: string): number {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const size = fs.statSync(file.fd).size; if (size >= 2147483648 || size < 22) throw new Error('请选择小于 2GB 的完整备份');
      const tailSize = Math.min(size, 65557); const tail = new DataView(this.readAt(file.fd, size - tailSize, tailSize)); let end = -1;
      for (let index = tailSize - 22; index >= 0; index--) { if (tail.getUint32(index, true) === 0x06054b50 && index + 22 + tail.getUint16(index + 20, true) === tailSize) { end = index; break; } }
      if (end < 0 || tail.getUint16(end + 4, true) || tail.getUint16(end + 6, true)) throw new Error('备份归档格式不支持');
      const count = tail.getUint16(end + 10, true); const directorySize = tail.getUint32(end + 12, true); const offset = tail.getUint32(end + 16, true);
      if (count === 65535 || directorySize > 32 * 1024 * 1024 || offset + directorySize > size) throw new Error('备份文件清单过大或不完整');
      const directory = new DataView(this.readAt(file.fd, offset, directorySize)); const names: string[] = []; let position = 0; let total = 0;
      for (let index = 0; index < count; index++) {
        if (position + 46 > directorySize || directory.getUint32(position, true) !== 0x02014b50) throw new Error('备份文件清单损坏');
        const flags = directory.getUint16(position + 8, true); const method = directory.getUint16(position + 10, true); const bytes = directory.getUint32(position + 24, true); const nameSize = directory.getUint16(position + 28, true); const extra = directory.getUint16(position + 30, true); const comment = directory.getUint16(position + 32, true); const attributes = directory.getUint32(position + 38, true); const localOffset = directory.getUint32(position + 42, true);
        if (position + 46 + nameSize + extra + comment > directorySize) throw new Error('备份路径不完整');
        const name = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(directory.buffer, position + 46, nameSize));
        if (!/^(manifest\.json|data\/[a-z-]+\.json|assets\/[a-zA-Z0-9-]+\.(jpg|jpeg|png|heif)|data\/|assets\/)$/.test(name) || names.includes(name) || flags & 1 || ![0,8].includes(method) || ((attributes >>> 16) & 0xf000) === 0xa000) throw new Error('备份包含不支持的路径或文件类型：' + name.slice(0,160));
        names.push(name); total += bytes;
        if (bytes === 0xffffffff || total >= 2147483648 || name.startsWith('assets/') && bytes > 30 * 1024 * 1024) throw new Error('备份解压体积超过限制');
        const header = new DataView(this.readAt(file.fd, localOffset, 30)); if (header.getUint32(0, true) !== 0x04034b50) throw new Error('备份文件头损坏');
        const localName = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(this.readAt(file.fd, localOffset + 30, header.getUint16(26, true))));
        if (localName !== name) throw new Error('备份文件路径校验失败');
        position += 46 + nameSize + extra + comment;
      }
      if (!names.includes('manifest.json')) throw new Error('这不是完整的我的家当备份');
      if (statfs.getFreeSizeSync(this.context.filesDir) < (size + total * 3) * 1.2) throw new Error('可用空间不足，请释放空间后再恢复');
      return total;
    } finally { fs.closeSync(file); }
  }
  private records<T>(root: string, name: string): T[] { const value = JSON.parse(fs.readTextSync(root + '/data/' + name + '.json')) as Envelope<T>; if (value.schemaVersion !== 1 || !Array.isArray(value.records) || value.records.length > 100000) throw new Error(name + ' 的版本或数量不支持'); return value.records; }
  async selectBackup(): Promise<RestorePreview | undefined> {
    this.cancelled = false; const selected = await new picker.DocumentViewPicker(this.context as common.UIAbilityContext).select({ maxSelectNumber: 1 }); if (!selected.length) return undefined;
    const file = this.context.cacheDir + '/import-' + uuid() + '.zip'; this.temporary.push(file); await this.copyFile(selected[0], file); return this.readArchive(file);
  }
  async readArchive(file: string): Promise<RestorePreview> {
    this.check(); this.progress('正在核对备份文件'); const expandedBytes = this.inspectZip(file);
    const root = this.context.cacheDir + '/restore-' + uuid(); this.temporary.push(root); fs.mkdirSync(root); await zlib.decompressFile(file, root); this.check();
    const preview = new RestorePreview(); preview.directory = root; preview.requiredBytes = Math.ceil(expandedBytes * 2.4);
    const manifest = JSON.parse(fs.readTextSync(root + '/manifest.json')) as Manifest;
    if (manifest.format !== 'itemnest' || manifest.formatVersion !== 1 || manifest.schemaVersion !== 1) throw new Error('备份版本不支持，请更新应用或选择其他备份');
    if (!Array.isArray(manifest.files) || !Array.isArray(manifest.assets) || typeof manifest.datasetId !== 'string' || !Number.isFinite(manifest.exportedAt) || !manifest.counts) throw new Error('备份清单字段不完整');
    const declared: string[] = []; const damaged: string[] = [];
    for (const entry of manifest.files) {
      this.check(); if (typeof entry.path !== 'string' || !/^(data\/[a-z-]+\.json|assets\/[a-zA-Z0-9-]+\.(jpg|jpeg|png|heif))$/.test(entry.path) || declared.includes(entry.path)) throw new Error('备份文件路径或重复条目无效'); declared.push(entry.path);
      if (!Number.isInteger(entry.byteSize) || entry.byteSize < 0 || !/^[a-fA-F0-9]{64}$/.test(entry.sha256)) throw new Error('备份文件字节数或校验值无效');
      const path = root + '/' + entry.path;
      if (!fs.accessSync(path) || fs.statSync(path).size !== entry.byteSize || await hash.hash(path, 'sha256') !== entry.sha256) {if(entry.path.startsWith('assets/'))damaged.push(entry.path);else throw new Error('文件缺失或校验不一致：' + entry.path);}
    }
    for (const table of ['locations','items','item-photos','item-dates','change-events','drafts','preferences']) { if (!declared.includes('data/' + table + '.json')) throw new Error('备份缺少 ' + table); }
    const data = new Snapshot(); data.items = this.records<Item>(root,'items'); data.locations = this.records<Location>(root,'locations'); data.events = this.records<ChangeEvent>(root,'change-events'); data.drafts = this.records<Draft>(root,'drafts'); data.preference = this.records<Preference>(root,'preferences')[0]; data.assets = manifest.assets;
    const photos = this.records<ItemPhoto>(root,'item-photos'); const dates = this.records<ItemDate>(root,'item-dates');
    if(photos.some((photo:ItemPhoto)=>!data.items.some((item:Item)=>item.id===photo.itemId) || !Number.isInteger(photo.order) || photo.order<0 || photo.order>5) || dates.some((date:ItemDate)=>!data.items.some((item:Item)=>item.id===date.itemId)))throw new Error('照片顺序或日期归属无效');
    data.items.forEach((item: Item) => { item.photoIds = photos.filter((photo: ItemPhoto) => photo.itemId === item.id).sort((a: ItemPhoto,b: ItemPhoto) => a.order-b.order).map((photo: ItemPhoto) => photo.assetId); item.dates = dates.filter((date: ItemDate) => date.itemId === item.id); });
    for (const asset of data.assets) {
      this.check(); if (!declared.includes(asset.relativePath) || !/^assets\/[a-zA-Z0-9-]+\.(jpg|jpeg|png|heif)$/.test(asset.relativePath)) throw new Error('照片引用无效');
      if(damaged.includes(asset.relativePath))continue;
      const path = root + '/' + asset.relativePath;
      try {
        if(fs.statSync(path).size!==asset.byteSize || await hash.hash(path,'sha256')!==asset.sha256)throw new Error('照片校验不一致');
        const source=image.createImageSource(path);
        try { const info=await source.getImageInfo(); if(info.size.width*info.size.height>48000000)throw new Error('照片过大'); const pixels=await source.createPixelMap({desiredSize:{width:Math.min(480,info.size.width),height:Math.min(480,info.size.height)}});await pixels.release(); }
        finally { await source.release(); }
      } catch(_) { damaged.push(asset.relativePath); }
    }
    const missing=data.assets.filter((asset:Asset)=>damaged.includes(asset.relativePath)).map((asset:Asset)=>asset.id);
    if(missing.length){
      data.assets=data.assets.filter((asset:Asset)=>!missing.includes(asset.id));
      const clean=(item:Item):void=>{const count=item.photoIds.filter((id:string)=>missing.includes(id)).length;if(count){item.missingPhotoCount=(item.missingPhotoCount??0)+count;preview.warnings.push(displayName(item)+'：'+count+' 张照片待补充');item.photoIds=item.photoIds.filter((id:string)=>!missing.includes(id));}};
      data.items.forEach(clean);data.drafts.forEach((draft:Draft)=>{clean(draft.payload);(draft.sharedItems??[]).forEach(clean);draft.assetIds=draft.assetIds.filter((id:string)=>!missing.includes(id));});
      data.locations.forEach((node:Location)=>{if(missing.includes(node.photoAssetId)){node.photoAssetId='';preview.warnings.push('位置 '+node.name+' 的照片待补充');}});
    }
    this.validate(data,true);
    data.preference.datasetId = manifest.datasetId; preview.manifest = manifest; preview.snapshot = data;
    data.items.forEach((item: Item) => {
      if (item.deletedAt && item.purgeAt <= Date.now()) preview.expired++;
      const current = this.repository.data.items.find((value: Item) => value.id === item.id);
      if (!current) preview.newItems++; else { preview.existingItems++; if (!this.sameContent(current, item)) { const conflict = new RestoreConflict(); conflict.id = item.id; conflict.kind = 'item'; conflict.title = displayName(item); conflict.current = displayName(current) + ' · ' + statusText(current) + ' · ' + new Date(current.updatedAt).toLocaleString('zh-CN',{hour12:false}); conflict.backup = displayName(item) + ' · ' + statusText(item) + ' · ' + new Date(item.updatedAt).toLocaleString('zh-CN',{hour12:false}); preview.conflicts.push(conflict); } }
    });
    data.locations.forEach((node: Location) => { const current = this.repository.data.locations.find((value: Location) => value.id === node.id); if (current && JSON.stringify(current) !== JSON.stringify(node)) { const conflict = new RestoreConflict(); conflict.kind='location'; conflict.id=node.id; conflict.title='位置：'+node.name; conflict.current=this.repository.path(current.id); conflict.backup=this.repository.path(node.id,data.locations); preview.conflicts.push(conflict); } });
    const locationMap=new Map<string,string>();
    for(let level=0;level<4;level++)data.locations.filter((node:Location)=>!locationMap.has(node.id) && (!node.parentId || locationMap.has(node.parentId))).forEach((node:Location)=>{
      const parent=locationMap.get(node.parentId)??node.parentId;const same=this.repository.data.locations.find((current:Location)=>current.id===node.id);const named=this.repository.data.locations.find((current:Location)=>current.parentId===parent && normalize(current.name)===normalize(node.name));
      locationMap.set(node.id,same?.id??named?.id??node.id);
      if(!same && named && (named.notes!==node.notes || named.photoAssetId!==node.photoAssetId)){const conflict=new RestoreConflict();conflict.kind='namedLocation';conflict.id=node.id;conflict.targetId=named.id;conflict.title='同名位置：'+node.name;conflict.current=named.notes || '当前位置';conflict.backup=node.notes || '备份位置';preview.conflicts.push(conflict);}
    });
    data.drafts.forEach((draft:Draft)=>{const current=this.repository.data.drafts.find((value:Draft)=>value.id===draft.id);if(current && JSON.stringify(current)!==JSON.stringify(draft)){const conflict=new RestoreConflict();conflict.kind='draft';conflict.id=draft.id;conflict.title='草稿：'+displayName(draft.payload);conflict.current='保留当前草稿';conflict.backup='另外导入一条备份草稿';preview.conflicts.push(conflict);}});
    return preview;
  }
  private sameContent(left: Item, right: Item): boolean { const a = copy(left); const b = copy(right); a.lastViewedAt = 0; b.lastViewedAt = 0; return JSON.stringify(a) === JSON.stringify(b); }
  private validate(data: Snapshot, allowMissing:boolean=false): void {
    const unique = (ids: string[]): void => { if (ids.length > 100000 || ids.some((id: string) => typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) || new Set(ids).size !== ids.length) throw new Error('记录标识或数量无效'); };
    unique(data.items.map((item: Item) => item.id)); unique(data.locations.map((node: Location) => node.id)); unique(data.assets.map((asset: Asset) => asset.id)); unique(data.drafts.map((draft: Draft) => draft.id)); unique(data.events.map((event: ChangeEvent) => event.id));
    unique(data.items.flatMap((item:Item)=>item.dates.map((date:ItemDate)=>date.id)));
    data.assets.forEach((asset: Asset) => { if (!Number.isInteger(asset.byteSize) || asset.byteSize <= 0 || asset.byteSize > 30 * 1024 * 1024 || !Number.isInteger(asset.width) || !Number.isInteger(asset.height) || asset.width < 1 || asset.height < 1 || asset.width * asset.height > 48000000 || !/^[a-fA-F0-9]{64}$/.test(asset.sha256)) throw new Error('照片资源描述无效'); });
    this.repository.validateLocations(data.locations);
    if (!data.preference || !['SYSTEM','LIGHT','DARK'].includes(data.preference.theme) || !Array.isArray(data.preference.searchHistory) || !Array.isArray(data.preference.cardIds)) throw new Error('偏好设置格式无效');
    data.locations.forEach((node:Location)=>{if(node.photoAssetId && !data.assets.some((asset:Asset)=>asset.id===node.photoAssetId))throw new Error('位置照片引用无效');});
    if(data.events.some((event:ChangeEvent)=>!data.items.some((item:Item)=>item.id===event.itemId) || typeof event.before!=='string' || typeof event.after!=='string' || !Number.isFinite(event.createdAt)))throw new Error('变化记录归属或内容无效');
    if(data.preference.cardIds.length>3 || data.preference.searchHistory.length>8 || !['SYSTEM','SIMPLE'].includes(data.preference.motion) || !['COMMON','DATES'].includes(data.preference.cardMode))throw new Error('偏好设置范围无效');
    data.items.forEach((item: Item) => {
      if (!CATEGORY_CODES.includes(item.category) || item.status === 'ARCHIVED' && !['USED_UP','GIVEN','SOLD','DISCARDED','OTHER'].includes(item.archiveReason)) throw new Error('分类或归档原因无效');
      if (typeof item.title !== 'string' || typeof item.notes !== 'string' || length(item.title)>80 || length(item.notes)>2000 || !Array.isArray(item.photoIds) || item.photoIds.length>6 || !allowMissing && !item.title.trim() && !item.photoIds.length || !['SINGLE','GROUP'].includes(item.kind) || !['ACTIVE','LENT','ARCHIVED'].includes(item.status) || !Number.isInteger(item.revision) || item.revision<1 || !Number.isFinite(item.createdAt) || !Number.isFinite(item.updatedAt)) throw new Error('物品字段无效');
      if (item.kind==='SINGLE' && (!Number.isInteger(item.quantity) || (item.quantity ?? 0)<0 || (item.quantity ?? 0)>9999 || item.status!=='ARCHIVED' && (item.quantity ?? 0)<1)) throw new Error('物品数量无效');
      if(item.kind==='GROUP'){item.quantity=null;if(item.archiveReason==='USED_UP')throw new Error('整组归档原因无效');}
      if(typeof item.barcodeValue!=='string' || length(item.barcodeValue)>256 || (!!item.barcodeValue!==!!item.barcodeType) || item.barcodeType && !['EAN13','EAN8','UPC_A','UPC_E','CODE128','QR'].includes(item.barcodeType))throw new Error('商品条码字段无效');
      if(item.deletedAt && (!Number.isFinite(item.deletedAt) || !Number.isFinite(item.purgeAt) || item.purgeAt<item.deletedAt))throw new Error('回收期限无效');
      if (!Array.isArray(item.aliases) || item.aliases.length>5 || item.aliases.some((value: string) => typeof value!=='string' || length(value)>30) || !Array.isArray(item.tags) || item.tags.length>10 || item.tags.some((value: string) => typeof value!=='string' || length(value)>20)) throw new Error('别名或标签格式无效');
      if (item.locationId && !data.locations.some((node: Location) => node.id===item.locationId) || item.photoIds.some((id: string) => !data.assets.some((asset: Asset) => asset.id===id))) throw new Error('物品的位置或照片引用缺失');
      if (item.status==='LENT' && (!item.borrower || length(item.borrower)>40)) throw new Error('借出称呼无效');
      if (!item.expiryInput) throw new Error('日期依据缺失'); const expiry = expiryDate(item.expiryInput);
      if (expiry !== (item.dates.find((date: ItemDate) => date.type === 'EXPIRY')?.date ?? '')) throw new Error('到期日期与计算依据不一致');
      const types: string[]=[]; item.dates.forEach((date: ItemDate) => { if (!validDate(date.date) || !['EXPIRY','WARRANTY','RETURN'].includes(date.type) || types.includes(date.type) || date.itemId!==item.id || !Number.isInteger(date.dateVersion) || date.dateVersion<1) throw new Error('物品日期无效'); types.push(date.type); });
    });
    data.drafts.forEach((draft: Draft) => { if (!draft.payload || !['CREATE','EDIT','SHARE'].includes(draft.mode) || !Array.isArray(draft.payload.photoIds) || [...draft.payload.photoIds,...(draft.sharedItems??[]).flatMap((item:Item)=>item.photoIds)].some((id: string) => !data.assets.some((asset: Asset) => asset.id===id))) throw new Error('草稿字段或照片引用缺失'); });
  }
  async restore(preview: RestorePreview, replace: boolean, restoreExpired: boolean): Promise<string> {
    this.check(); this.progress('正在准备恢复'); const incoming = copy(preview.snapshot); const current = copy(this.repository.data);
    const currentIds = current.items.map((item: Item) => item.id);
    incoming.items = incoming.items.filter((item: Item) => { if (item.deletedAt && item.purgeAt <= Date.now()) { if (!restoreExpired) return false; item.deletedAt=0; item.purgeAt=0; } return true; });
    incoming.events=incoming.events.filter((event:ChangeEvent)=>incoming.items.some((item:Item)=>item.id===event.itemId));
    incoming.drafts=incoming.drafts.filter((draft:Draft)=>draft.mode!=='EDIT' || incoming.items.some((item:Item)=>item.id===draft.itemId));
    const result = replace ? incoming : current;
    if (!replace) {
      const assetMap=new Map<string,string>();
      incoming.assets.forEach((asset:Asset)=>{const match=current.assets.find((value:Asset)=>value.sha256===asset.sha256 && value.byteSize===asset.byteSize);if(match)assetMap.set(asset.id,match.id);});
      incoming.items.forEach((item:Item)=>item.photoIds=item.photoIds.map((id:string)=>assetMap.get(id)??id));
      incoming.locations.forEach((node:Location)=>node.photoAssetId=assetMap.get(node.photoAssetId)??node.photoAssetId);
      incoming.drafts.forEach((draft:Draft)=>{draft.payload.photoIds=draft.payload.photoIds.map((id:string)=>assetMap.get(id)??id);draft.assetIds=draft.assetIds.map((id:string)=>assetMap.get(id)??id);(draft.sharedItems??[]).forEach((item:Item)=>item.photoIds=item.photoIds.map((id:string)=>assetMap.get(id)??id));});
      incoming.assets=incoming.assets.filter((asset:Asset)=>!assetMap.has(asset.id));
      const map = new Map<string,string>(); const pending = copy(incoming.locations);
      for (let level=0; level<4; level++) {
        pending.filter((node: Location) => !map.has(node.id) && (!node.parentId || map.has(node.parentId))).forEach((node: Location) => {
          node.parentId = map.get(node.parentId) ?? node.parentId; const same = result.locations.find((value: Location) => value.id===node.id);
          const named = result.locations.find((value: Location) => value.parentId===node.parentId && normalize(value.name)===normalize(node.name));
          if (same) { if (preview.conflicts.some((entry: RestoreConflict) => entry.kind==='location' && entry.id===node.id && entry.useBackup)) result.locations=result.locations.map((value: Location) => value.id===node.id ? node : value); map.set(node.id,node.id); }
          else if (named) {map.set(node.id,named.id);if(preview.conflicts.some((entry:RestoreConflict)=>entry.kind==='namedLocation' && entry.id===node.id && entry.useBackup)){named.notes=node.notes;named.photoAssetId=node.photoAssetId;named.revision++;named.updatedAt=Date.now();}}
          else { result.locations.push(node); map.set(node.id,node.id); }
        });
      }
      if (map.size !== incoming.locations.length) throw new Error('位置关系无法合并，请选择其他冲突处理方式');
      incoming.items.forEach((item: Item) => {
        item.locationId=map.get(item.locationId) ?? item.locationId; const old=result.items.find((value: Item) => value.id===item.id);
        if (!old || preview.conflicts.some((entry: RestoreConflict) => entry.kind==='item' && entry.id===item.id && entry.useBackup)) {
          result.items=result.items.filter((value: Item) => value.id!==item.id); result.items.push(item);
          result.events=result.events.filter((event: ChangeEvent) => event.itemId!==item.id); result.events.push(...incoming.events.filter((event: ChangeEvent) => event.itemId===item.id));
        }
      });
      incoming.drafts.forEach((draft:Draft)=>{const exists=result.drafts.some((value:Draft)=>value.id===draft.id);if(exists && preview.conflicts.some((entry:RestoreConflict)=>entry.kind==='draft' && entry.id===draft.id && entry.useBackup)){draft.id=uuid();draft.sessionId=uuid();}else if(exists)return;draft.payload.locationId=map.get(draft.payload.locationId)??draft.payload.locationId;(draft.sharedItems??[]).forEach((item:Item)=>item.locationId=map.get(item.locationId)??item.locationId);result.drafts.push(draft);});
      incoming.assets.forEach((asset: Asset) => { const existing=result.assets.find((value: Asset) => value.id===asset.id); if (!existing) result.assets.push(asset); else if (existing.sha256!==asset.sha256) throw new Error('同一照片标识内容不同，无法安全合并'); });
    }
    this.validate(result); this.check();
    const currentBytes = current.assets.reduce((sum: number, asset: Asset) => sum + asset.byteSize, 0) + JSON.stringify(current).length * 3;
    const incomingBytes = incoming.assets.reduce((sum: number, asset: Asset) => sum + asset.byteSize, 0) + JSON.stringify(incoming).length * 3;
    if (statfs.getFreeSizeSync(this.context.filesDir) < (incomingBytes + (replace ? currentBytes * 2 : 0)) * 1.2) throw new Error('可用空间不足，尚未替换当前家当，请先释放空间');
    if (replace) { this.progress('正在保存替换前的保护快照'); const protection=this.context.filesDir+'/protection.zip'; await this.archive(current,protection+'.new.zip'); fs.renameSync(protection+'.new.zip',protection); this.write(this.context.filesDir+'/protection.json',JSON.stringify({ createdAt: Date.now(), expiresAt: Date.now()+7*86400000 })); }
    this.progress('正在保存照片'); const dir=this.context.filesDir+'/assets'; if(!fs.accessSync(dir))fs.mkdirSync(dir);
    const copied: string[] = [];
    try {
      for(const asset of incoming.assets){this.check();const path=this.context.filesDir+'/'+asset.relativePath;if(fs.accessSync(path)){if(await hash.hash(path,'sha256')!==asset.sha256)throw new Error('现有照片与备份冲突');}else { copied.push(path); await this.copyFile(preview.directory+'/'+asset.relativePath,path); }}
      this.check();this.progress('正在保存家当');this.repository.replaceSnapshot(result);
    } catch (error) { copied.forEach((path: string) => { try { if (fs.accessSync(path)) fs.unlinkSync(path); } catch (_) {} }); throw error as Error; }
    const added = incoming.items.filter((item: Item) => !currentIds.includes(item.id)).length;
    const updated = replace ? incoming.items.length - added : preview.conflicts.filter((conflict: RestoreConflict) => conflict.kind === 'item' && conflict.useBackup && incoming.items.some((item: Item) => item.id === conflict.id)).length;
    const future = result.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED').reduce((count: number, item: Item) => count + item.dates.filter((date: ItemDate) => !date.handledAt && date.remindEnabled && new Date(date.date + 'T09:00:00').getTime() > Date.now()).length, 0);
    return `恢复完成：${result.items.length} 条记录、${result.locations.length} 个位置、${result.assets.length} 张照片。\n新增 ${added} 条，采用备份 ${updated} 条，保留当前 ${replace ? 0 : currentIds.length - updated} 条；照片待补充 ${preview.warnings.length} 项。\n${future} 项未来日期将按当前设备权限重新安排。`;
  }
  async protection(): Promise<RestorePreview> { this.cancelled=false;const path=this.context.filesDir+'/protection.zip'; if(!fs.accessSync(path))throw new Error('还没有替换保护快照'); const metadata=JSON.parse(fs.readTextSync(this.context.filesDir+'/protection.json')) as Record<string,number>; if(metadata.expiresAt<Date.now())throw new Error('保护快照已超过 7 天保留期'); return this.readArchive(path); }
}
