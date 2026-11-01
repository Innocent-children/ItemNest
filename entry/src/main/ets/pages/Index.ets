import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { ActionButton, SectionHeading, MenuRow } from '../components/Common';
import { common, ConfigurationConstant, abilityAccessCtrl } from '@kit.AbilityKit';
import { Item, Draft, ItemDate, Location, Snapshot, Preference, ChangeEvent, copy, uuid, displayName, statusText, localDate, setDate, shortDate, relativeDue, daysUntil, friendlyTime, firstGlyph, dateTypeName, reminderClock, CATEGORY_CODES, CATEGORY_NAMES } from '../model/Models';
import { LengthMetrics } from '@kit.ArkUI';
import { LocationPicker } from '../components/LocationPicker';
import { Repository } from '../data/Repository';
import { MediaService } from '../services/MediaService';
import { ItemEditor } from '../components/ItemEditor';
import { DataPage } from '../components/DataPage';
import { VoicePanel } from '../components/VoicePanel';
import { CalendarService, ReminderResult } from '../services/CalendarService';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { IncomingShare } from '../services/ShareService';
import { SharePanel } from '../components/SharePanel';
import { CardService } from '../services/CardService';
import { PhotoViewer } from '../components/PhotoViewer';

interface ItemRows { values: Item[]; here?: string; }
interface DateRow { item: Item; date: ItemDate; }

@Entry
@Component
struct Index {
  private repository: Repository = new Repository();
  private tabsController:HdsTabsController=new HdsTabsController();
  private homeScroller:Scroller=new Scroller();
  private locationScroller:Scroller=new Scroller();
  private mineScroller:Scroller=new Scroller();
  @State contentWidth:number=390;
  @StorageProp('fontScale') fontScale:number=1;
  private stack: NavPathStack = new NavPathStack();
  @State data: Snapshot = new Snapshot();
  @State ready: boolean = false;
  @State failure: string = '';
  @State tab: number = 0;
  @State filter: string = '全部';
  @State category: string = '';
  @State query: string = '';
  @State scope: string = 'CURRENT';
  @State results: Item[] = [];
  @State selected: string[] = [];
  @State selecting: boolean = false;
  @State editorOpen: boolean = false;
  @State editorDraft: Draft = new Draft();
  @State focusedId: string = '';
  @State focusedLocation: string = '';
  @State includeChildren: boolean = true;
  @State panel: string = '';
  @State panelOpen: boolean = false;
  @State value: string = '';
  @State quantity: string = '1';
  @State targetLocation: string = '';
  @State returnDate: string = '';
  @State keepDates: boolean = true;
  @State archiveReason: string = 'OTHER';
  @State locationForm: Location = new Location();
  @State panelError: string = '';
  @State handled: boolean = false;
  @State searchFilters: boolean = false;
  @State moreActions: boolean = false;
  @State historyOpen: boolean = false;
  @State previewPhoto: string = '';
  @State previewPhotos: string[] = [];
  @State photoZoom: number = 1;
  @State example: boolean = false;
  @StorageProp('entryAction') @Watch('routeEntry') entryAction: string = '';
  @StorageProp('foregroundAt') @Watch('foreground') foregroundAt: number = 0;
  private queryTimer: number = -1;
  private calendar?: CalendarService;
  @State reminderResults: ReminderResult[] = [];
  @State voiceOpen: boolean = false;
  @State barcode: string = '';
  @State barcodeType: string = 'EAN13';
  @State scanning: boolean = false;
  @StorageProp('incomingAt') @Watch('readShares') incomingAt:number=0;
  @StorageProp('entryError') @Watch('showEntryError') entryError:string='';
  private readingShares:boolean=false;
  private readSharesAgain:boolean=false;
  private cardTimer:number=-1;
  @State shareOpen:boolean=false;
  @State shareDraft:Draft=new Draft();
  @State pageSize:number=60;
  private pendingAction: string = '';
  private pendingItemId: string = '';
  private showEntryError():void {if(this.entryError){this.notify(this.entryError);AppStorage.set('entryError','');}}
  private async readShares():Promise<void> {
    if(!this.ready)return;if(this.readingShares){this.readSharesAgain=true;return;}this.readingShares=true;
    try {
      const directory=(this.getUIContext().getHostContext() as common.UIAbilityContext).filesDir+'/incoming';if(!fs.accessSync(directory))return;
      for(const name of fs.listFileSync(directory).filter((value:string)=>value.endsWith('.json'))) {
        const incoming=JSON.parse(fs.readTextSync(directory+'/'+name)) as IncomingShare;
        const existing=this.repository.data.drafts.find((draft:Draft)=>draft.sessionId===incoming.id);
        const draft=existing?copy(existing):new Draft();draft.mode='SHARE';draft.sessionId=incoming.id;draft.shareSourceCount=incoming.count;
        let failed=incoming.errors;
        for(const path of incoming.files) {
          if(!fs.accessSync(path))continue;
          try {const asset=await this.media().importImage(path);const item=new Item();item.photoIds=[asset.id];draft.sharedItems.push(item);this.repository.saveDraft(draft);fs.unlinkSync(path);}
          catch(_){failed++;}
        }
        if(draft.sharedItems.length){this.repository.saveDraft(draft);if(!this.editorOpen && !this.shareOpen && !this.panelOpen){this.shareDraft=copy(draft);this.shareOpen=true;}}
        fs.unlinkSync(directory+'/'+name);
        incoming.files.forEach((path:string)=>{if(fs.accessSync(path))fs.unlinkSync(path);});
        if(failed)this.notify('部分图片未能加入，请重新分享或从相册选择');
      }
      this.refresh();
    } catch(error){this.notify((error as Error).message);}finally{this.readingShares=false;if(this.readSharesAgain){this.readSharesAgain=false;this.readShares();}}
  }
  @Builder share(){SharePanel({repository:this.repository,initial:this.shareDraft,onClose:()=>{this.shareOpen=false;this.refresh();},onView:(id:string)=>{this.shareOpen=false;this.refresh();this.detail(id);}})}
  private async scan(): Promise<void> {
    if (this.scanning) return; this.scanning = true;
    try {
      if(!scanCore.isDefaultScanSupported())throw new Error('设备暂不支持系统扫码');
      const result = await scanBarcode.startScanForResult(this.getUIContext().getHostContext() as common.UIAbilityContext, { scanTypes: [scanCore.ScanType.EAN13_CODE, scanCore.ScanType.EAN8_CODE, scanCore.ScanType.UPC_A_CODE, scanCore.ScanType.UPC_E_CODE, scanCore.ScanType.CODE128_CODE, scanCore.ScanType.QR_CODE] });
      const types: number[] = [scanCore.ScanType.EAN13_CODE, scanCore.ScanType.EAN8_CODE, scanCore.ScanType.UPC_A_CODE, scanCore.ScanType.UPC_E_CODE, scanCore.ScanType.CODE128_CODE, scanCore.ScanType.QR_CODE];
      this.barcodeType = ['EAN13','EAN8','UPC_A','UPC_E','CODE128','QR'][types.indexOf(result.scanType)]; this.barcode = result.originalValue;
      if (!this.barcodeType || !this.barcode || this.barcode.length>256) throw new Error('请选择有效商品条码');
    } catch (error) { this.notify('可继续手动输入条码，或重新扫一扫'); } finally { this.scanning = false; }
  }
  private sameItem(source?: Item): void { const draft = new Draft(); if(source) { draft.payload.title=source.title; draft.payload.category=source.category; } draft.payload.barcodeType=this.barcodeType;draft.payload.barcodeValue=this.barcode;this.editorDraft=draft;this.editorOpen=true; }
  @Builder scanPage() {
    Text('扫一扫，看看自己是否记过').fontSize(22).fontColor($r('app.color.text'))
    ActionButton({ label: this.scanning ? '正在扫码' : '打开系统扫码', run: () => this.scan(), primary: true })
    TextInput({ text: this.barcode, placeholder: '也可以输入条码数字，开头的 0 也要保留' }).maxLength(256).onChange((value:string)=>this.barcode=value)
    Select([{value:'EAN13'},{value:'EAN8'},{value:'UPC_A'},{value:'UPC_E'},{value:'CODE128'},{value:'QR'}]).value(this.barcodeType).onSelect((index:number)=>this.barcodeType=['EAN13','EAN8','UPC_A','UPC_E','CODE128','QR'][index])
    if(this.barcode) {
      ForEach(this.data.items.filter((item:Item)=>!item.deletedAt && item.barcodeType===this.barcodeType && item.barcodeValue===this.barcode),(item:Item)=>{this.itemRow(item,'');ActionButton({ label: '再记同款', run: ()=>this.sameItem(item) });},(item:Item)=>item.id)
      ActionButton({ label: '把这件记下来', run: ()=>this.sameItem(), primary: true })
    }
  }
  @Builder reminderSettings() {
    Text(this.data.preference.reminderEnabled ? '到期提醒已开启' : '让日期到了有个提醒').fontSize(24).fontColor($r('app.color.text'))
    Text('到期当天上午 9:00 提醒，同一天合成一条。开启后将日期写入系统日历，用于提醒。').fontColor($r('app.color.secondary'))
    ActionButton({ label: this.data.preference.reminderEnabled ? '关闭到期提醒' : '开启系统日历提醒', run: ()=>{
      if(this.data.preference.reminderEnabled){this.preference((pref:Preference)=>pref.reminderEnabled=false);this.calendar?.sync();}
      else this.calendar?.enable().catch((error:Error)=>this.notify(error.message));
    }, primary: true })
    if (this.reminderResults.some((result: ReminderResult) => result.state === 'PENDING')) { ActionButton({ label: '重新核对安排', run: ()=>this.calendar?.sync() }) }
    if (this.reminderResults.some((result: ReminderResult) => result.state === 'CANCEL_PENDING')) {
      Text('只清理“我的家当”尚未到时的提醒日程，物品日期会保留。').fontColor($r('app.color.secondary'))
      ActionButton({ label: '允许访问并清理提醒日程', run: ()=>{this.calendar?.enable().then(()=>{this.preference((pref:Preference)=>pref.reminderEnabled=false);this.calendar?.sync();}).catch((error:Error)=>this.notify(error.message));} })
    }
    Row() { Text('外部提醒显示物品名称').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.data.preference.externalDetails }).onChange((value: boolean) => this.preference((pref: Preference) => pref.externalDetails = value)); }.width('100%')
    ForEach(this.reminderResults,(result:ReminderResult)=>{Text(result.message).fontSize(15).fontColor($r('app.color.secondary'));},(result:ReminderResult)=>result.day+result.state+result.message)
  }
  @Builder voice() { VoicePanel({target:'搜索词',currentValue:this.query,maxLength:100,onAdopt:(value:string)=>{this.query=value;this.voiceOpen=false;this.submitSearch();},onCancel:()=>this.voiceOpen=false}) }

  aboutToAppear(): void { this.fontScale=(this.getUIContext().getHostContext() as common.UIAbilityContext).config.fontSizeScale??1;this.open(); }
  aboutToDisappear():void {clearTimeout(this.queryTimer);clearTimeout(this.cardTimer);this.tabsController.unbindScroller(this.homeScroller);this.tabsController.unbindScroller(this.locationScroller);this.tabsController.unbindScroller(this.mineScroller);}
  private async open(): Promise<void> {
    try {
      await this.repository.open(this.getUIContext().getHostContext() as common.UIAbilityContext);
      this.repository.maintain(this.getUIContext().getHostContext() as common.UIAbilityContext);
      this.repository.onChange = () => this.refresh(); this.refresh(); this.tab = this.data.preference.lastTab;
      this.ready = true;
      this.calendar = new CalendarService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository);
      this.calendar.onChange = () => this.reminderResults = this.calendar?.results ?? [];
      this.calendar.sync(); this.applyTheme(); this.routeEntry(); this.readShares(); this.search();
    } catch (error) { this.failure = `读取遇到问题：${(error as Error).message}`; }
  }
  private refresh(): void { this.data = copy(this.repository.data); this.search(); if(this.ready) {this.calendar?.sync();clearTimeout(this.cardTimer);this.cardTimer=setTimeout(()=>CardService.refresh(this.repository).catch(()=>{}),250);} }
  private media(): MediaService { return new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository); }
  private foreground(): void { if (this.ready) { this.repository.reload(); this.repository.maintain(this.getUIContext().getHostContext() as common.UIAbilityContext); this.refresh(); this.readShares(); } }
  private routeEntry(): void {
    if (!this.ready || !this.entryAction) return;
    const action = this.entryAction; AppStorage.set('entryAction', '');
    if (this.editorOpen || this.shareOpen || this.panelOpen || this.voiceOpen) {
      this.pendingAction = action; this.pendingItemId = AppStorage.get<string>('entryItemId') ?? '';
      this.notify('入口已保留，完成当前操作后继续'); return;
    }
    if (action === 'capture') this.newItem();
    else if (action === 'search') { this.scope = 'CURRENT'; this.query = ''; this.filter = '全部'; this.category = ''; this.search(); this.navigate('搜索'); }
    else if (action === 'dates') this.navigate('提醒');
    else if (action === 'scan') this.navigate('扫码查同款');
    else if(action==='item'){const id=AppStorage.get<string>('entryItemId')??'';if(this.data.items.some((item:Item)=>item.id===id && !item.deletedAt))this.detail(id);else this.notify('这条记录已移除，可以继续查找');}
  }
  private resumeEntry(): void {
    this.refresh(); if (!this.pendingAction) return;
    const action = this.pendingAction; this.pendingAction = '';
    AppStorage.setOrCreate('entryItemId', this.pendingItemId); AppStorage.setOrCreate('entryAction', action);
  }
  private applyTheme(): void {
    this.stack.disableAnimation(this.data.preference.motion==='SIMPLE');
    const mode = this.data.preference.theme;
    (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext().setColorMode(mode === 'DARK' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : mode === 'LIGHT' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }
  private preference(change: (value: Preference) => void): void { const value = copy(this.data.preference); change(value); this.repository.savePreference(value); this.applyTheme(); }
  private notify(message: string): void { this.getUIContext().getPromptAction().showToast({ message, duration: 3000 }); }
  private act(run: () => void, message: string = '已保存'): void { try { run(); this.refresh(); if (message) this.notify(message); } catch (error) { this.notify((error as Error).message); } }
  private navigate(name: string): void { this.stack.pushPath({ name, param: name==='位置详情'?this.focusedLocation:name==='物品详情'?this.focusedId:'' }); }
  private detail(id: string): void { this.focusedId = id; this.moreActions = false; this.historyOpen = false; this.repository.viewed(id); this.refresh(); this.navigate('物品详情'); }
  private current(): Item { return this.data.items.find((item: Item) => item.id === this.focusedId) ?? new Item(); }
  private openPhoto(ids: string[], id: string): void { this.previewPhotos = [...ids]; this.previewPhoto = id; this.navigate('照片'); }
  private location(): Location { return this.data.locations.find((location: Location) => location.id === this.focusedLocation) ?? new Location(); }
  private locationParents(): Location[] { return this.data.locations.filter((node: Location) => this.repository.canReparent(this.locationForm.id, node.id)); }
  private dateRows(section: string): DateRow[] {
    const rows: DateRow[] = [];
    this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED').forEach((item: Item) => item.dates.forEach((date: ItemDate) => {
      if (!!date.handledAt !== this.handled) return;
      const days = daysUntil(date.date);
      const group = date.handledAt ? '已处理' : days < 0 ? '已过期' : days === 0 ? '今天' : days <= 7 ? '7 天内' : days <= 30 ? '30 天内' : '以后';
      if (!section || group === section) rows.push({ item, date });
    }));
    return rows.sort((a: DateRow, b: DateRow) => a.date.date.localeCompare(b.date.date) || a.date.id.localeCompare(b.date.id));
  }
  private dateArrangement(date: ItemDate): string {
    if (date.handledAt) return '已处理';
    if (daysUntil(date.date) < 0) return '处理后会移到“已处理”';
    if (new Date(date.date + 'T09:00:00').getTime() <= Date.now()) return '今天的提醒时间已过';
    if (!date.remindEnabled) return '这项不提醒';
    if (!this.data.preference.reminderEnabled) return '提醒未开启';
    return this.reminderResults.find((result: ReminderResult) => result.day === date.date)?.message ?? '等待写入系统日历';
  }
  // 30 天内到期或已经过期、尚未处理的日期，按日期先后排列
  private upcoming(): DateRow[] {
    const rows: DateRow[] = [];
    this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED').forEach((item: Item) => item.dates.forEach((date: ItemDate) => { if (!date.handledAt && daysUntil(date.date) <= 30) rows.push({ item, date }); }));
    return rows.sort((a: DateRow, b: DateRow) => a.date.date.localeCompare(b.date.date));
  }
  private dueBadge(item: Item): string {
    const dates = item.dates.filter((date: ItemDate) => !date.handledAt && daysUntil(date.date) <= 30).sort((a: ItemDate, b: ItemDate) => a.date.localeCompare(b.date));
    return dates.length ? relativeDue(dates[0].date, dates[0].type) : '';
  }
  private latestDraft(): Draft | undefined { return [...this.data.drafts].sort((a: Draft, b: Draft) => b.updatedAt - a.updatedAt)[0]; }
  private historyLines(event: ChangeEvent): string[] {
    const after = event.after.split('\n'); const before = event.before ? event.before.split('\n') : [];
    const structured = /^[^\s：]{2}：/.test(event.after) || (!event.after && !event.before);
    if (!structured) {
      // 旧版本记录保存的是整条摘要，按“ · ”分段后只列出不同的段落
      if (!event.before) return [event.after.split(' · ').filter((part: string) => !part.endsWith('：')).join(' · ')];
      if (event.before === event.after) return [];
      const old = event.before.split(' · '); const now = event.after.split(' · ');
      if (old.length !== now.length) return ['原来：' + event.before, '现在：' + event.after];
      return now.map((part: string, index: number) => old[index] === part ? '' : old[index] + ' → ' + part).filter((line: string) => !!line);
    }
    if (!before.length) return after.filter((line: string) => !!line);
    return after.map((line: string, index: number) => { const label = line.split('：')[0]; return label + '：' + (before[index] ?? '').slice(label.length + 1) + ' → ' + line.slice(label.length + 1); });
  }
  private matchText(item: Item): string {
    if (!this.query.trim()) return '';
    const words = this.query.toLowerCase().trim().split(/\s+/);
    const values = ['别名：' + item.aliases.join('、'), '标签：' + item.tags.join('、'), '说明：' + item.notes];
    return values.filter((value: string) => words.some((word: string) => value.toLowerCase().includes(word))).join(' · ');
  }
  private newItem(location: string = '', title: string = ''): void {
    const begin = () => { const draft = new Draft(); draft.payload.locationId = location; draft.payload.title = title; this.editorDraft = draft; this.editorOpen = true; };
    // 只在一小时内有未完成的记录时询问；更早的草稿留在首页和“我的 → 草稿”，不再拦住记录入口
    const recent = this.latestDraft();
    if (recent && recent.mode !== 'SHARE' && Date.now() - recent.updatedAt < 3600000 && !location && !title) {
      this.getUIContext().showAlertDialog({ title: '继续刚才的记录？', message: `“${displayName(recent.payload)}”还没有保存。`, primaryButton: { value: '另记一条', action: begin }, secondaryButton: { value: '继续这条', action: () => this.resume(recent) } });
    } else begin();
  }
  private edit(item: Item): void { const draft = new Draft(); draft.mode = 'EDIT'; draft.itemId = item.id; draft.baseRevision = item.revision; draft.payload = copy(item); this.editorDraft = draft; this.editorOpen = true; }
  private resume(draft: Draft): void { if(draft.mode==='SHARE'){this.shareDraft=copy(draft);this.shareOpen=true;}else{this.editorDraft = copy(draft); this.editorOpen = true;} }
  private search(): void { if (this.ready || this.repository.data.items.length) this.results = this.repository.search(this.query, this.scope, this.filter, this.category); }
  private submitSearch(): void {
    this.search(); const query = this.query.trim();
    if (query) this.preference((pref: Preference) => pref.searchHistory = [query, ...pref.searchHistory.filter((entry: string) => entry !== query)].slice(0, 8));
  }
  private toggle(id: string): void { this.selected = this.selected.includes(id) ? this.selected.filter((value: string) => value !== id) : [...this.selected, id]; }
  private confirm(title: string, message: string, action: () => void): void { this.getUIContext().showAlertDialog({ title, message, primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: title, action: () => this.act(action) } }); }
  private openPanel(name: string): void {
    const item = this.current(); this.panel = name; this.panelError = ''; this.value = name === '拆分数量' ? item.title : item.borrower; this.quantity = String(name === '拆分数量' ? 1 : Math.max(1, item.quantity ?? 1)); this.targetLocation = item.locationId; this.returnDate = ''; this.keepDates = true; this.panelOpen = true;
  }
  private async locationPhoto(camera:boolean):Promise<void>{
    try{const media=this.media();const uris=camera?await media.camera():await media.pick(1);if(!uris.length)return;const asset=await media.importImage(uris[0]);this.locationForm.photoAssetId=asset.id;this.locationForm=copy(this.locationForm);}catch(error){this.panelError=(error as Error).message;}
  }
  private openLocationForm(edit: boolean = false): void { this.locationForm = edit ? copy(this.location()) : new Location(); if (!edit) this.locationForm.parentId = this.focusedLocation; this.panel = '管理位置'; this.panelError = ''; this.panelOpen = true; }
  private editingLocation(): boolean { return this.data.locations.some((node: Location) => node.id === this.locationForm.id); }
  private panelTitle(): string { return this.panel === '管理位置' ? (this.editingLocation() ? '编辑位置' : this.locationForm.parentId ? '新建子位置' : '新建位置') : this.panel; }
  private submitPanel(): void {
    try {
      const id = this.focusedId; const target = this.targetLocation;
      if (this.panel === '管理位置') this.repository.saveLocation(this.locationForm);
      else if (this.panel === '移除位置') { this.repository.deleteLocation(this.focusedLocation, target); this.stack.pop(); }
      else if (this.panel === '拆分数量') {const next=this.repository.split(id,Number(this.quantity),this.value,target,this.keepDates);this.detail(next);}
      else if (this.panel === '批量移位置') this.repository.mutate(this.selected, '批量移位置', (item: Item) => item.locationId = target);
      else this.repository.mutate([id], this.panel, (item: Item) => {
        if (this.panel === '改位置') item.locationId = target;
        if (this.panel === '调整数量') { item.quantity = Number(this.quantity); if (item.quantity === 0) { item.status = 'ARCHIVED'; item.archiveReason = 'USED_UP'; item.archivedAt = Date.now(); } }
        if (this.panel === '借出') { item.status = 'LENT'; item.borrower = this.value.trim(); item.lentAt = Date.now(); setDate(item, 'RETURN', this.returnDate); }
        if (this.panel === '已归还') { item.status = 'ACTIVE'; item.borrower = ''; item.lentAt = 0; item.locationId = target; item.dates.filter((date: ItemDate) => date.type === 'RETURN').forEach((date: ItemDate) => date.handledAt = Date.now()); }
        if (this.panel === '归档') { item.status = 'ARCHIVED'; item.archiveReason = this.archiveReason; item.archivedAt = Date.now(); item.borrower = ''; item.lentAt = 0; if (this.archiveReason === 'USED_UP') item.quantity = 0; }
        if (this.panel === '恢复到家当') { item.status = 'ACTIVE'; item.quantity = Number(this.quantity); item.locationId = target; item.archiveReason = ''; item.archivedAt = 0; }
        if (this.panel === '恢复记录') { item.deletedAt = 0; item.purgeAt = 0; item.locationId = target; }
      });
      this.panelOpen = false; this.selected = []; this.selecting = false; this.refresh(); this.notify('已保存');
    } catch (error) { this.panelError = (error as Error).message; }
  }
  @Builder empty(title: string, subtitle: string) {
    Column({ space: 14 }) { Image($r('app.media.foreground')).width(150).height(150).objectFit(ImageFit.Contain); Text(title).fontSize(23).fontColor($r('app.color.text')); Text(subtitle).fontSize(15).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center) }.width('100%').padding({ top: 28, bottom: 24 })
  }
  @Builder glyph(item: Item, size: number) {
    Text(firstGlyph(item)).fontSize(size * 0.42).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary')).width(size).height(size).textAlign(TextAlign.Center).backgroundColor($r('app.color.subtle')).borderRadius(14)
  }
  @Builder itemRow(item: Item, here: string) {
    Row({ space: 12 }) {
      if (this.selecting) { Checkbox({ name: item.id }).select(this.selected.includes(item.id)).accessibilityText('选择' + displayName(item)).onChange((selected: boolean) => { this.selected = selected ? Array.from(new Set([...this.selected, item.id])) : this.selected.filter((id: string) => id !== item.id); }) }
      if (item.photoIds.length) { Image(this.media().uri(item.photoIds[0], true)).width(64).height(64).objectFit(ImageFit.Cover).borderRadius(14).accessibilityText(displayName(item) + '主图') }
      else { this.glyph(item, 64) }
      Column({ space: 4 }) {
        Text(displayName(item)).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (!here || item.locationId !== here) { Text(this.repository.path(item.locationId) || '位置待补充').fontSize(13).fontColor($r('app.color.secondary')).maxLines(2) }
        Text(statusText(item) + (item.favorite ? ' · 常用' : '')).fontSize(12).fontColor($r('app.color.primary'))
        if (this.matchText(item)) { Text(this.matchText(item)).fontSize(13).fontColor($r('app.color.secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
        if (item.dates.some((date: ItemDate) => !date.handledAt)) { Text(item.dates.filter((date: ItemDate) => !date.handledAt).map((date: ItemDate) => daysUntil(date.date) <= 60 ? relativeDue(date.date, date.type) : dateTypeName(date.type) + ' ' + shortDate(date.date)).join(' · ')).fontSize(12).fontColor(item.dates.some((date: ItemDate) => !date.handledAt && daysUntil(date.date) <= 7) ? $r('app.color.warning') : $r('app.color.secondary')).maxLines(3) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(12).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(() => this.selecting ? this.toggle(item.id) : this.detail(item.id)).gesture(LongPressGesture().onAction(() => { this.selecting = true; this.selected = [item.id]; }))
  }
  @Builder items($$: ItemRows) {
    ForEach($$.values.slice(0, this.pageSize), (item: Item) => this.itemRow(item, $$.here ?? ''), (item: Item) => item.id + ':' + item.revision)
    if($$.values.length>this.pageSize){ActionButton({ label: `继续显示（已显示 ${this.pageSize} / ${$$.values.length}）`, run: ()=>this.pageSize+=60 })}
  }
  @Builder filters() {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(['全部', '常用', '借出', '整组'], (name: string) => { ActionButton({ label: name, tonal: this.filter === name, run: () => { this.filter = name; this.search(); } }) })
        Select(CATEGORY_NAMES.map((name: string, index: number): SelectOption => ({ value: index ? name : '全部分类' }))).value(this.category ? CATEGORY_NAMES[CATEGORY_CODES.indexOf(this.category)] : '全部分类').font({ size: 15 }).fontColor($r('app.color.primary')).backgroundColor(this.category ? $r('app.color.subtle') : Color.Transparent).height(44).onSelect((index: number) => { this.category = CATEGORY_CODES[index]; this.search(); })
        if (this.category || this.filter !== '全部') { ActionButton({ label: '清除', run: () => { this.filter = '全部'; this.category = ''; this.search(); } }) }
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
  }
  @Builder batch() {
    if (this.selecting) {
      Row({ space: 8 }) { Text(`已选 ${this.selected.length} 条`).layoutWeight(1).fontColor($r('app.color.text')); ActionButton({ label: '全选', run: () => this.selected = this.results.map((item: Item) => item.id) }); ActionButton({ label: '完成', run: () => { this.selecting = false; this.selected = []; } }) }
      Row({ space: 8 }) {
        ActionButton({ label: '移位置', run: () => this.openPanel('批量移位置') })
        ActionButton({ label: '移入回收站', run: () => this.confirm('移入回收站', `将 ${this.selected.length} 条记录移入回收站，保留 30 天。`, () => { this.repository.recycle(this.selected); this.selected = []; this.selecting = false; }) })
      }.enabled(this.selected.length > 0)
    }
  }
  @Builder home() {
    Row() {
      Text('我的家当').fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
      Blank()
      if (this.data.items.some((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED')) { Text(`${this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED').length} 条记录`).fontSize(14).fontColor($r('app.color.secondary')) }
    }.width('100%').padding({ top: 12 })
    Row({ space: 10 }) { Text('⌕').fontSize(20).fontColor($r('app.color.secondary')); Text('找东西：名称、拼音、说明或位置').fontSize(16).fontColor($r('app.color.secondary')) }
      .width('100%').height(50).padding({ left: 18, right: 18 }).backgroundColor($r('app.color.surface')).borderRadius(25).accessibilityText('找东西').accessibilityLevel('yes')
      .onClick(() => { this.scope = 'CURRENT'; this.query = ''; this.search(); this.navigate('搜索'); })
    if (this.upcoming().length) {
      Column({ space: 6 }) {
        Row() { Text(this.upcoming().some((row: DateRow) => daysUntil(row.date.date) < 0) ? '有日期需要处理' : '快到期了').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.warning')); Blank(); Text(`${this.upcoming().length} 项 ›`).fontSize(14).fontColor($r('app.color.secondary')) }.width('100%')
        ForEach(this.upcoming().slice(0, 3), (row: DateRow) => {
          Row() { Text(displayName(row.item)).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(relativeDue(row.date.date, row.date.type)).fontSize(14).fontColor(daysUntil(row.date.date) <= 2 ? $r('app.color.warning') : $r('app.color.secondary')) }.width('100%')
        }, (row: DateRow) => row.date.id + ':' + row.date.date)
      }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(() => this.navigate('提醒')).accessibilityLevel('yes')
    }
    if (this.latestDraft()) {
      Row({ space: 8 }) {
        Text('继续刚才的记录：' + displayName((this.latestDraft() ?? new Draft()).payload)).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('›').fontSize(22).fontColor($r('app.color.secondary'))
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).backgroundColor($r('app.color.subtle')).borderRadius(16).onClick(() => { const draft = this.latestDraft(); if (draft) this.resume(draft); })
    }
    if (this.data.items.some((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED')) { this.filters(); this.batch() }
    if (!this.results.length) {
      this.empty(this.data.items.length ? '这里还没有对应记录' : '记住放哪，用好已有', '先记一件你以后会找的东西')
      ActionButton({ label: '记下一件', run: () => this.newItem(), primary: true })
      ActionButton({ label: '看看示例', run: () => { this.example = true; this.navigate('示例家当'); } })
    } else { this.homeGrid() }
  }
  @Builder homeGrid(){
    if(this.contentWidth<360 || this.fontScale>1.3){this.items({ values: this.results })}else{
      GridRow({columns:this.contentWidth>=600?3:2,gutter:12}){
        ForEach(this.results.slice(0,this.pageSize),(item:Item)=>{
          GridCol(){
            Column({space:8}){
              if(item.photoIds.length){Image(this.media().uri(item.photoIds[0],true)).width('100%').aspectRatio(1.1).objectFit(ImageFit.Cover).borderRadius(14)}else{this.glyph(item,44)}
              Text((this.selecting?(this.selected.includes(item.id)?'☑ ':'☐ '):'')+displayName(item)).fontSize(16).fontColor($r('app.color.text')).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')
              Text(this.repository.path(item.locationId)||'位置待补充').fontSize(12).fontColor($r('app.color.secondary')).maxLines(2).width('100%')
              Text(statusText(item)+(item.favorite?' · 常用':'')).fontSize(12).fontColor($r('app.color.primary')).width('100%')
              if (this.dueBadge(item)) { Text(this.dueBadge(item)).fontSize(12).fontColor($r('app.color.warning')).width('100%') }
            }.alignItems(HorizontalAlign.Start).padding(12).width('100%').backgroundColor($r('app.color.surface')).borderRadius(20).onClick(()=>this.selecting?this.toggle(item.id):this.detail(item.id)).gesture(LongPressGesture().onAction(()=>{this.selecting=true;this.selected=[item.id];}))
          }
        },(item:Item)=>item.id+':'+item.revision)
      }.width('100%')
      if(this.results.length>this.pageSize){ActionButton({label:'继续显示更多',run:()=>this.pageSize+=60})}
    }
  }
  @Builder searchPage() {
    if (this.voiceOpen) { this.voice() }
    Search({ value: this.query, placeholder: '名称、拼音、说明、位置' }).id('searchInput').height(52).maxLength(100).defaultFocus(true)
      .onAppear(() => setTimeout(() => { try { this.getUIContext().getFocusController().requestFocus('searchInput'); } catch (_) {} }, 350)).onChange((value: string, preview: PreviewText) => { this.query = value; clearTimeout(this.queryTimer); if (!preview.value) this.queryTimer = setTimeout(() => this.search(), 200); }).onSubmit(() => this.submitSearch())
    Row({space:8}) {ActionButton({ label: '扫一扫', run: ()=>this.navigate('扫码查同款') });ActionButton({ label: '语音查找', run: ()=>this.voiceOpen=true });ActionButton({label: this.searchFilters ? '收起筛选' : (this.category || this.filter !== '全部' || this.scope !== 'CURRENT' ? '筛选 · 已选' : '筛选'), run:()=>this.searchFilters=!this.searchFilters});}
    if (this.searchFilters) {
    Row({ space: 8 }) { ActionButton({ label: this.scope === 'CURRENT' ? '✓ 在手与借出' : '在手与借出', run: () => { this.scope = 'CURRENT'; this.search(); } }); ActionButton({ label: this.scope === 'ARCHIVED' ? '✓ 归档' : '归档', run: () => { this.scope = 'ARCHIVED'; this.search(); } }) }
    this.filters()
    }
    this.batch()
    if (!this.query) {
      if (this.data.preference.searchHistory.length) {
        Row() { Text('最近搜索').fontSize(16).fontColor($r('app.color.secondary')); Blank(); ActionButton({ label: '清空', run: () => this.preference((pref: Preference) => pref.searchHistory = []) }) }.width('100%')
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.data.preference.searchHistory, (value: string) => { ActionButton({ label: value, tonal: true, run: () => { this.query = value; this.submitSearch(); } }) }, (value: string) => value)
        }.width('100%')
      }
      MenuRow({ title: '按位置找', subtitle: '按自己的收纳习惯浏览', action: () => { this.stack.clear(); this.tab = 1; } })
      if (this.data.items.some((item: Item) => item.lastViewedAt > 0 && !item.deletedAt && (this.scope === 'ARCHIVED' ? item.status === 'ARCHIVED' : item.status !== 'ARCHIVED'))) { Text('最近查看').fontSize(16).fontColor($r('app.color.secondary')) }
      this.items({ values: this.data.items.filter((item: Item) => item.lastViewedAt > 0 && !item.deletedAt && (this.scope === 'ARCHIVED' ? item.status === 'ARCHIVED' : item.status !== 'ARCHIVED')).sort((a: Item, b: Item) => b.lastViewedAt - a.lastViewedAt).slice(0, 6) })
    } else if (this.results.length) { this.items({ values: this.results }) }
    else {
      Column({ space: 10 }) {
        Text(`没有找到“${this.query}”`).fontSize(20).fontColor($r('app.color.text'))
        Text('如果它就在手边，现在记下来，下次一搜就有。').fontSize(15).fontColor($r('app.color.secondary'))
        ActionButton({ label: `记下“${this.query}”`, run: () => this.newItem('', this.query), primary: true })
        ActionButton({ label: '按位置找', run: () => { this.stack.clear(); this.tab = 1; } })
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 24 })
    }
  }
  @Builder locations(root: boolean = false) {
    if (root) SectionHeading({ title: '位置', subtitle: '从最容易想到的地方开始' })
    ForEach(this.data.locations.filter((location: Location) => location.parentId === (root ? '' : this.focusedLocation)).sort((a: Location, b: Location) => a.sortOrder - b.sortOrder), (location: Location) => {
      MenuRow({ title: location.name, subtitle: `${this.repository.search('', 'CURRENT', '', '', location.id).length} 条记录` + (this.data.locations.some((node: Location) => node.parentId === location.id) ? ` · ${this.data.locations.filter((node: Location) => node.parentId === location.id).length} 个子位置` : ''), action: () => { this.focusedLocation = location.id; this.navigate('位置详情'); } })
    }, (location: Location) => location.id + ':' + location.revision)
    ActionButton({ label: root ? '新建位置' : '在这里新建子位置', tonal: true, run: () => { if (root) this.focusedLocation = ''; this.openLocationForm(); } })
  }
  @Builder locationDetail() {
    SectionHeading({ title: this.location().name, subtitle: this.location().parentId ? '在 ' + this.repository.path(this.location().parentId) : '' })
    if(this.location().photoAssetId){Image(this.media().uri(this.location().photoAssetId)).width('100%').aspectRatio(1.5).objectFit(ImageFit.Cover).borderRadius(20).onClick(()=>this.openPhoto([this.location().photoAssetId],this.location().photoAssetId))}
    if (this.location().notes) { Text(this.location().notes).fontColor($r('app.color.secondary')) }
    Row({ space: 8 }) { ActionButton({ label: '在这里记下', run: () => this.newItem(this.focusedLocation), primary: true }); ActionButton({ label: '编辑位置', tonal: true, run: () => this.openLocationForm(true) }); }
    this.locations()
    if (this.data.locations.some((node: Location) => node.parentId === this.focusedLocation)) {
      Row({ space: 6 }) { ActionButton({ label: '包含子位置', tonal: this.includeChildren, run: () => this.includeChildren = true }); ActionButton({ label: '只看这一层', tonal: !this.includeChildren, run: () => this.includeChildren = false }); }
    }
    this.items({ values: this.repository.search('', 'CURRENT', '', '', this.focusedLocation, this.includeChildren), here: this.focusedLocation })
    ActionButton({ label: '移除这个位置', danger: true, run: () => this.openPanel('移除位置') })
  }
  @Builder details() {
    if (!this.data.items.some((item: Item) => item.id === this.focusedId)) { this.empty('这条记录已移除', '返回家当查看其他记录') }
    else {
      if (this.current().photoIds.length) {
        Swiper() { ForEach(this.current().photoIds, (id: string) => { Image(this.media().uri(id)).width('100%').aspectRatio(4 / 3).objectFit(ImageFit.Cover).borderRadius(20).onClick(() => this.openPhoto(this.current().photoIds, id)) }) }.width('100%').aspectRatio(4 / 3)
      }
      SectionHeading({ title: displayName(this.current()), subtitle: statusText(this.current()) })
      MenuRow({ title: this.current().status === 'LENT' ? '归还时放回' : '放在这里', subtitle: this.repository.path(this.current().locationId) || '位置待补充', action: () => this.openPanel('改位置') })
      if (this.current().status === 'ACTIVE' && !this.current().deletedAt && this.current().locationId) { Text(this.current().locationConfirmedAt ? '上次确认在这里：' + friendlyTime(this.current().locationConfirmedAt) : '找到实物后，可以确认位置').fontSize(13).fontColor($r('app.color.secondary')) }
      if (!this.current().deletedAt && this.current().status === 'LENT') { ActionButton({label:'已归还', primary:true, run:()=>this.openPanel('已归还')}) }
      if (!this.current().deletedAt && this.current().status === 'ACTIVE') {
        Row({ space: 8 }) { if (this.current().locationId) { ActionButton({ label: '在这里找到了', tonal: true, run: () => this.act(() => this.repository.mutate([this.focusedId], '确认位置', (item: Item) => item.locationConfirmedAt = Date.now()), '位置已确认') }) } ActionButton({ label: this.current().locationId ? '改位置' : '补上位置', tonal: true, run: () => this.openPanel('改位置') }); }
      }
      if(this.current().missingPhotoCount){Text(`${this.current().missingPhotoCount} 张原照片待补充，可在编辑中重新添加`).fontColor($r('app.color.warning'))}
      if (this.current().sourceItemId) { MenuRow({ title: '从原记录拆出', subtitle: this.data.items.find((item: Item) => item.id === this.current().sourceItemId)?.title || '查看来源记录', action: () => { const source = this.data.items.find((item: Item) => item.id === this.current().sourceItemId); if (source) this.detail(source.id); else this.notify('来源记录已移除，拆分历史仍保留'); } }) }
      if (this.current().deletedAt && this.current().previousLocationPath) { Text('回收时位置：' + this.current().previousLocationPath).fontColor($r('app.color.secondary')) }
      if (this.current().notes) { Text(this.current().notes).fontSize(17).fontColor($r('app.color.text')).copyOption(CopyOptions.InApp) }
      if (this.current().aliases.length) { Text('别名：' + this.current().aliases.join('、')).fontColor($r('app.color.secondary')) }
      if (this.current().tags.length) { Text('标签：' + this.current().tags.join('、')).fontColor($r('app.color.secondary')) }
      ForEach(this.current().dates, (date: ItemDate) => { MenuRow({ title: date.handledAt ? dateTypeName(date.type) + ' · ' + shortDate(date.date) : relativeDue(date.date, date.type) + '（' + shortDate(date.date) + '）', subtitle: date.handledAt ? '已处理' : this.dateArrangement(date), action: () => this.navigate('提醒') }) }, (date: ItemDate) => date.id + ':' + date.dateVersion + ':' + date.handledAt)
      if (this.current().deletedAt) {
        Text('保留至 ' + friendlyTime(this.current().purgeAt)).fontColor($r('app.color.warning'))
        ActionButton({ label: '恢复记录', run: () => this.openPanel('恢复记录'), primary: true })
        ActionButton({ label: '永久删除', danger: true, run: () => this.confirm('永久删除', `删除“${displayName(this.current())}”及 ${this.repository.unreferencedPhotoCount(this.focusedId)} 张不再被其他记录引用的照片。此操作无法撤销。`, () => { this.repository.purge([this.focusedId]); this.stack.pop(); }) })
      } else if (this.current().status === 'ARCHIVED') { ActionButton({ label: '恢复到家当', run: () => this.openPanel('恢复到家当'), primary: true }) }
      else {
        ActionButton({ label: '编辑', run: () => this.edit(this.current()), primary: this.current().status === 'ACTIVE' })
        Row({ space: 8 }) { ActionButton({ label: this.current().favorite ? '取消常用' : '设为常用', tonal: true, run: () => this.act(() => this.repository.mutate([this.focusedId], '修改常用', (item: Item) => item.favorite = !item.favorite)) }); if (this.current().status === 'ACTIVE') { ActionButton({ label: '借出', tonal: true, run: () => this.openPanel('借出') }); } }
        ActionButton({label:this.moreActions?'收起更多操作':'更多操作',run:()=>this.moreActions=!this.moreActions})
        if (this.moreActions) {
        if (this.current().kind === 'SINGLE') { Row({ space: 8 }) { ActionButton({ label: '调整数量', tonal: true, run: () => this.openPanel('调整数量') }); if ((this.current().quantity ?? 0) > 1 && this.current().status === 'ACTIVE') { ActionButton({ label: '拆分数量', tonal: true, run: () => this.openPanel('拆分数量') }) } } }
        ActionButton({ label: '在此位置记一件', tonal: true, run: () => this.newItem(this.current().locationId) })
        Row({ space: 8 }) { ActionButton({ label: '归档（用完、送出等）', run: () => this.openPanel('归档') }); ActionButton({ label: '移入回收站', danger: true, run: () => this.confirm('移入回收站', '记录与照片保留 30 天，可从“我的 → 归档与回收站”恢复。', () => { this.repository.recycle([this.focusedId]); this.stack.pop(); }) }); }
        }
      }
      ActionButton({label:this.historyOpen?'收起变化记录':'变化记录',run:()=>this.historyOpen=!this.historyOpen})
      if (this.historyOpen) {
      ForEach(this.data.events.filter((event: ChangeEvent) => event.itemId === this.focusedId).sort((a: ChangeEvent, b: ChangeEvent) => b.createdAt - a.createdAt), (event: ChangeEvent) => {
        Column({ space: 4 }) { Text(event.type + ' · ' + friendlyTime(event.createdAt)).fontSize(14).fontColor($r('app.color.text')); ForEach(this.historyLines(event), (line: string) => { Text(line).fontSize(13).fontColor($r('app.color.secondary')) }, (line: string, index: number) => index + line) }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 6, bottom: 6 })
      }, (event: ChangeEvent) => event.id)
      }
    }
  }
  @Builder mine() {
    SectionHeading({ title: '我的', subtitle: `单件记录 ${this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'SINGLE').length} 条 · 整组记录 ${this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'GROUP').length} 组` })
    Text(`在手单件数量 ${this.data.items.filter((item: Item) => !item.deletedAt && item.status === 'ACTIVE' && item.kind === 'SINGLE').reduce((sum: number, item: Item) => sum + (item.quantity ?? 0), 0)} 件`).fontSize(20).fontColor($r('app.color.primary'))
    MenuRow({ title: '常用', subtitle: '常找的物品放在手边', action: () => { this.tab = 0; this.filter = '常用'; this.scope = 'CURRENT'; this.search(); } })
    MenuRow({ title: '草稿', subtitle: `${this.data.drafts.length} 条未完成记录`, action: () => this.navigate('草稿') })
    MenuRow({ title: '提醒', subtitle: this.upcoming().length ? `${this.upcoming().length} 项 30 天内到期或已过期` : '到期、保修、归还日期', action: () => this.navigate('提醒') })
    MenuRow({ title: '归档与回收站', subtitle: '查看历史，恢复记录', action: () => { this.scope = 'ARCHIVED'; this.query = ''; this.search(); this.navigate('归档与回收站'); } })
    MenuRow({ title: '数据管理', subtitle: this.data.preference.lastBackupAt ? '最近备份：' + friendlyTime(this.data.preference.lastBackupAt) : '制作一份完整备份', action: () => this.navigate('数据管理') })
    MenuRow({ title: '外观与隐私', subtitle: '主题、动效、卡片与权限', action: () => this.navigate('外观与隐私') })
    MenuRow({ title: '帮助与关于', subtitle: '怎样记录，怎样长期保存', action: () => this.navigate('帮助与关于') })
  }
  @Builder drafts() {
    if (!this.data.drafts.length) { this.empty('没有未完成的草稿', '下次输入会自动保留在这里') }
    ForEach(this.data.drafts, (draft: Draft) => { MenuRow({ title: displayName(draft.payload), subtitle: '上次编辑：' + friendlyTime(draft.updatedAt), action: () => this.resume(draft) }); ActionButton({ label: '删除此草稿', danger: true, run: () => this.confirm('删除草稿', '只移除此未提交草稿，正式物品保留。', () => this.repository.deleteDraft(draft.id)) }); }, (draft: Draft) => draft.id)
  }
  @Builder reminders() {
    MenuRow({ title: '到期提醒', subtitle: this.data.preference.reminderEnabled ? `已开启 · 当天 ${reminderClock()} 提醒，同一天合成一条` : '未开启 · 点击开启系统日历提醒', action: () => this.navigate('到期提醒') })
    Row({space:6}) { ActionButton({label:'待关注',tonal:!this.handled,run:()=>this.handled=false});ActionButton({label:'已处理',tonal:this.handled,run:()=>this.handled=true}); }
    if (!this.dateRows('').length) { Text(this.handled ? '还没有处理完成的日期' : '暂时没有需要关注的日期').fontColor($r('app.color.secondary')) }
    ForEach(this.handled ? ['已处理'] : ['已过期', '今天', '7 天内', '30 天内', '以后'], (section: string) => {
      if (this.dateRows(section).length) { Text(section).fontSize(17).fontWeight(FontWeight.Medium).fontColor(section === '已过期' || section === '今天' ? $r('app.color.warning') : $r('app.color.text')).margin({ top: 6 }) }
      ForEach(this.dateRows(section), (row: DateRow) => {
        Column({ space: 4 }) {
          Row() { Text(displayName(row.item)).fontSize(17).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text('›').fontSize(22).fontColor($r('app.color.secondary')) }.width('100%')
          Text((row.date.handledAt ? dateTypeName(row.date.type) + ' ' : relativeDue(row.date.date, row.date.type) + ' · ') + shortDate(row.date.date)).fontSize(14).fontColor(!row.date.handledAt && daysUntil(row.date.date) <= 2 ? $r('app.color.warning') : $r('app.color.secondary'))
          Text(this.dateArrangement(row.date)).fontSize(13).fontColor($r('app.color.secondary'))
        Row({ space: 4 }) {
          ActionButton({ label: this.handled ? '重新关注' : '处理完成', tonal: true, run: () => this.act(() => this.repository.mutate([row.item.id], this.handled ? '重新关注' : '处理日期', (item: Item) => { const date = item.dates.find((value: ItemDate) => value.id === row.date.id); if (date) { date.handledAt = this.handled ? 0 : Date.now(); date.updatedAt = Date.now(); if (this.handled) date.dateVersion++; } })) })
          ActionButton({ label: '改日期', run: () => this.edit(row.item) })
        if (!this.handled && daysUntil(row.date.date) >= 0) { ActionButton({ label: row.date.remindEnabled ? '不再提醒' : '恢复提醒', run: () => this.act(() => this.repository.mutate([row.item.id], '调整日期提醒', (item: Item) => { const date = item.dates.find((value: ItemDate) => value.id === row.date.id); if (date) { date.remindEnabled = !date.remindEnabled; date.dateVersion++; date.handledAt = 0; date.updatedAt = Date.now(); } }), row.date.remindEnabled ? '这项日期不再提醒' : '已恢复提醒') }) }
        }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 12, top: 12, bottom: 4 }).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(() => this.detail(row.item.id))
      }, (row: DateRow) => row.date.id + ':' + row.item.revision)
    })
    ForEach(this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.expiryInput.mode === 'SHELF_LIFE' && !item.expiryInput.producedOn), (item: Item) => { MenuRow({ title: displayName(item), subtitle: '补上生产日期可计算到期日', action: () => this.edit(item) }) })
  }
  @Builder history() {
    Row({ space: 8 }) { ActionButton({ label: '归档', run: () => { this.scope = 'ARCHIVED'; this.search(); } }); ActionButton({ label: '回收站', run: () => { this.scope = 'TRASH'; this.search(); } }); }
    Search({ value: this.query, placeholder: '搜索当前历史范围' }).maxLength(100).onChange((value: string, preview: PreviewText) => { this.query = value; clearTimeout(this.queryTimer); if (!preview.value) this.queryTimer = setTimeout(() => this.search(), 200); })
    this.items({ values: this.results })
  }
  @Builder settings() {
    Text('主题').fontSize(20).fontColor($r('app.color.text'))
    Row({ space: 6 }) { ForEach(['SYSTEM', 'LIGHT', 'DARK'], (mode: string, index: number) => { ActionButton({ label: ['跟随系统', '浅色', '深色'][index], tonal: this.data.preference.theme === mode, run: () => this.preference((pref: Preference) => pref.theme = mode) }) }) }
    MenuRow({ title: '动效表现', subtitle: this.data.preference.motion === 'SIMPLE' ? '简洁' : '跟随系统', action: () => this.preference((pref: Preference) => pref.motion = pref.motion === 'SIMPLE' ? 'SYSTEM' : 'SIMPLE') })
    Text('字体与字号跟随系统设置。照片、名称和位置均保存在这台设备的应用空间中。').fontColor($r('app.color.secondary')).fontSize(15)
    ActionButton({ label: '管理日历访问权限', run: () => abilityAccessCtrl.createAtManager().openPermissionOnSetting(this.getUIContext().getHostContext() as common.UIAbilityContext, 'ohos.permission.READ_CALENDAR').catch(() => this.notify('可在系统设置 → 应用 → 我的家当 → 权限中管理')) })
    ActionButton({ label: '管理麦克风权限', run: () => abilityAccessCtrl.createAtManager().openPermissionOnSetting(this.getUIContext().getHostContext() as common.UIAbilityContext, 'ohos.permission.MICROPHONE').catch(() => this.notify('可在系统设置 → 应用 → 我的家当 → 权限中管理')) })
    MenuRow({ title: '到期提醒', subtitle: this.data.preference.reminderEnabled ? '已开启' : '未开启', action: () => this.navigate('到期提醒') })
    Row() { Text('外部提醒显示物品名称').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.data.preference.externalDetails }).onChange((value: boolean) => this.preference((pref: Preference) => pref.externalDetails = value)); }.width('100%')
    Row() { Text('在卡片展示物品摘要').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.data.preference.cardSummary }).onChange((value: boolean) => this.preference((pref: Preference) => pref.cardSummary = value)); }.width('100%')
    if(this.data.preference.cardSummary){
      Select([{value:'常用摘要'},{value:'日期摘要'}]).value(this.data.preference.cardMode==='DATES'?'日期摘要':'常用摘要').onSelect((index:number)=>this.preference((pref:Preference)=>pref.cardMode=index?'DATES':'COMMON'))
      if(this.data.preference.cardMode==='COMMON'){
        Text('选择最多 3 条记录，名称与位置会显示在桌面 2×4 卡片中').fontColor($r('app.color.secondary'))
        ForEach(this.data.items.filter((item:Item)=>!item.deletedAt && item.status!=='ARCHIVED' && item.favorite),(item:Item)=>{
          Row(){Checkbox({name:item.id}).select(this.data.preference.cardIds.includes(item.id)).onChange((selected:boolean)=>{if(selected && this.data.preference.cardIds.length>=3){this.notify('最多选择 3 条');return;}this.preference((pref:Preference)=>pref.cardIds=selected?[...pref.cardIds,item.id]:pref.cardIds.filter((id:string)=>id!==item.id));});Text(displayName(item)).fontColor($r('app.color.text')).layoutWeight(1);}
        },(item:Item)=>item.id)
      }
    }
    MenuRow({ title: '桌面随手可达', subtitle: '长按应用图标可添加卡片，或直接记一件、找东西、看临期、扫一扫。', action: ()=>this.navigate('快捷入口') })
    Text('系统日历仅接收提醒日期与数量；开启详情后包含名称。系统备份按系统设置处理应用数据，导出文件保存在你选择的位置。').fontSize(15).fontColor($r('app.color.secondary'))
  }
  @Builder help() {
    this.empty('我的家当', '1.0.0 · 记住放哪，用好已有')
    MenuRow({ title: '先记下一件', subtitle: '写个名字或选张照片，就能保存；位置可以以后补充。', action: () => this.newItem() })
    MenuRow({ title: '一箱东西也能记', subtitle: '用整组记录留下照片和内容说明，以后可以按说明搜索。', action: () => this.newItem() })
    MenuRow({ title: '找到后顺手更新', subtitle: '在详情确认位置、改位置、调整数量或记录借出与归还。', action: () => { this.stack.clear(); this.tab = 0; } })
    MenuRow({ title: '长期保存自己的记录', subtitle: '完整备份包含照片与草稿；清单用于阅读，恢复使用完整备份文件。', action: () => this.navigate('数据管理') })
  }
  @Builder movePicker() {
    LocationPicker({ repository: this.repository, selected: this.panel === '批量移位置' ? '' : this.current().locationId, title: this.panel === '批量移位置' ? `把 ${this.selected.length} 条记录移到` : '放到哪里', emptyLabel: '移出位置（待补充）', cancelLabel: '取消', onChoose: (id: string) => { this.targetLocation = id; this.submitPanel(); }, onCancel: () => this.panelOpen = false })
  }
  @Builder targetPicker() {
    Text('选择位置').fontColor($r('app.color.secondary'))
    Select([{ value: '位置待补充' }, ...this.data.locations.map((node: Location): SelectOption => ({ value: this.repository.path(node.id) }))]).value(this.repository.path(this.targetLocation) || '位置待补充').onSelect((index: number) => this.targetLocation = index ? this.data.locations[index - 1].id : '')
  }
  @Builder actionPanel() {
    Scroll() {
    Column({ space: 16 }) {
      if (this.panel === '改位置' || this.panel === '批量移位置') { this.movePicker() }
      else {
      Text(this.panelTitle()).fontSize(24).fontColor($r('app.color.text'))
      if (this.panel === '管理位置') {
        if(this.locationForm.photoAssetId){Image(this.media().uri(this.locationForm.photoAssetId,true)).width(100).height(80).objectFit(ImageFit.Cover).borderRadius(12);ActionButton({label:'移除位置照片',run:()=>{this.locationForm.photoAssetId='';this.locationForm=copy(this.locationForm);}});}
        Row({space:8}){ActionButton({label:'拍位置照片',run:()=>this.locationPhoto(true)});ActionButton({label:'选择照片',run:()=>this.locationPhoto(false)});}
        TextInput({ text: this.locationForm.name, placeholder: '位置名称，例如：第二层' }).maxLength(30).onChange((value: string) => { this.locationForm.name = value; this.locationForm = copy(this.locationForm); })
        Text('放在哪个位置里面').fontSize(14).fontColor($r('app.color.secondary'))
        Select([{ value: '不放在其他位置里（顶层）' }, ...this.locationParents().map((node: Location): SelectOption => ({ value: this.repository.path(node.id) }))]).value(this.repository.path(this.locationForm.parentId) || '不放在其他位置里（顶层）').onSelect((index: number) => { this.locationForm.parentId = index ? this.locationParents()[index - 1].id : ''; this.locationForm = copy(this.locationForm); })
        TextArea({ text: this.locationForm.notes, placeholder: '位置说明（选填），例如：左边柜门里' }).onChange((value: string) => { this.locationForm.notes = value; this.locationForm = copy(this.locationForm); })
        if (this.editingLocation()) { Row({ space: 8 }) { Text('排列顺序').fontSize(14).fontColor($r('app.color.secondary')); ActionButton({ label: '往前', run: () => this.act(() => this.repository.reorderLocation(this.locationForm.id, -1), '已调整顺序') }); ActionButton({ label: '往后', run: () => this.act(() => this.repository.reorderLocation(this.locationForm.id, 1), '已调整顺序') }); } }
      } else {
        if (['调整数量', '拆分数量', '恢复到家当'].includes(this.panel) && this.current().kind==='SINGLE') { TextInput({ text: this.quantity, placeholder: '数量' }).type(InputType.Number).onChange((value: string) => this.quantity = value) }
        if (this.panel === '调整数量' && this.quantity === '0') { Text('将归档为已用完，原数量保留在变化记录中').fontColor($r('app.color.warning')) }
        if (this.panel === '归档' && this.current().status === 'LENT') { Text('本次将结束借给' + this.current().borrower + '的记录，历史保留借出对象和数量').fontColor($r('app.color.warning')) }
        if (this.panel === '拆分数量') { TextInput({ text: this.value, placeholder: '新记录名称' }).onChange((value: string) => this.value = value); Text(`原数量 ${this.current().quantity}，拆分后剩余 ${(this.current().quantity ?? 0) - Number(this.quantity)}`).fontColor($r('app.color.secondary')); Row() { Text('沿用日期').fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.keepDates }).onChange((value: boolean) => this.keepDates = value); } }
        if (this.panel === '借出') {
          TextInput({ text: this.value, placeholder: '借给谁（称呼）' }).onChange((value: string) => this.value = value)
          MenuRow({title:'归还日期',subtitle:this.returnDate || '选填',action:()=>this.getUIContext().showDatePickerDialog({start:new Date(1900,0,1),end:new Date(2200,11,31),selected:this.returnDate?new Date(this.returnDate+'T12:00:00'):new Date(),onDateAccept:(date:Date)=>this.returnDate=localDate(date)})})
          if(this.returnDate){ActionButton({label:'清除归还日期',run:()=>this.returnDate=''})}
        }
        if (['改位置', '拆分数量', '已归还', '恢复到家当', '恢复记录', '批量移位置', '移除位置'].includes(this.panel)) { this.targetPicker() }
        if (this.panel === '批量移位置') { Text(`将 ${this.selected.length} 条记录移到 ${this.repository.path(this.targetLocation) || '位置待补充'}`).fontColor($r('app.color.text')) }
        if (this.panel === '移除位置') { Text(`将 ${this.data.items.filter((item:Item)=>item.locationId===this.focusedLocation).length} 条直属记录（含回收站）及 ${this.data.locations.filter((node:Location)=>node.parentId===this.focusedLocation).length} 个子位置迁入所选位置，再移除“${this.location().name}”。`).fontColor($r('app.color.text')) }
        if (this.panel === '归档') { Select([{ value: '其他' }, { value: '送出' }, { value: '出售' }, { value: '丢弃' }, { value: '用完（单件）' }]).value('选择归档原因').onSelect((index: number) => this.archiveReason = ['OTHER', 'GIVEN', 'SOLD', 'DISCARDED', 'USED_UP'][index]) }
      }
      if (this.panelError) { Text(this.panelError).fontColor($r('app.color.danger')) }
      ActionButton({ label: this.panel === '管理位置' ? '保存位置' : '确认' + this.panel, run: () => this.submitPanel(), primary: true })
      }
    }.padding({ left: 24, right: 24, top: 8, bottom: 32 }).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').align(Alignment.TopStart).backgroundColor($r('app.color.background'))
  }
  @Builder destination(name: string) {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          if (name === '搜索') { this.searchPage() }
          else if (name === '物品详情') { this.details() }
          else if (name === '位置详情') { this.locationDetail() }
          else if (name === '草稿') { this.drafts() }
          else if (name === '提醒') { this.reminders() }
          else if (name === '归档与回收站') { this.history() }
          else if (name === '外观与隐私') { this.settings() }
          else if (name === '帮助与关于') { this.help() }
          else if (name === '数据管理') { DataPage({repository:this.repository,onDone:()=>{this.stack.clear();this.tab=0;this.query='';this.scope='CURRENT';this.filter='全部';this.category='';this.refresh();}}) }
          else if (name === '到期提醒') { this.reminderSettings() }
          else if (name === '扫码查同款') { this.scanPage() }
          else if(name==='快捷入口'){SectionHeading({ title: '随手记下，快速找到', subtitle: '长按桌面的我的家当图标可添加 2×2 或 2×4 卡片' });ActionButton({ label: '记一件', run: ()=>this.newItem() });ActionButton({ label: '找东西', run: ()=>this.navigate('搜索') });ActionButton({ label: '看临期', run: ()=>this.navigate('提醒') });ActionButton({ label: '扫一扫', run: ()=>this.navigate('扫码查同款') });Text('卡片默认只显示入口；开启摘要后，2×4 卡片最多显示三条记录及更新时间。').fontColor($r('app.color.secondary'));}
          else if (name === '照片') { PhotoViewer({ repository: this.repository, ids: this.previewPhotos, initialId: this.previewPhoto, onSelect: (id: string) => this.previewPhoto = id }); if (this.current().photoIds.includes(this.previewPhoto) && !this.current().deletedAt && this.current().status !== 'ARCHIVED') { ActionButton({ label: '设为主图', run: () => this.confirm('设为主图', '将当前照片放到这条记录的第一张', () => this.repository.mutate([this.focusedId], '调整主图', (item: Item) => item.photoIds = [this.previewPhoto, ...item.photoIds.filter((id: string) => id !== this.previewPhoto)])) }); ActionButton({ label: '编辑照片与提取文字', run: () => this.edit(this.current()) }); } }
          else if (name === '示例家当') { SectionHeading({ title: '示例家当', subtitle: '此处展示独立示例' }); MenuRow({ title: '旅行充电器', subtitle: '书房 / 书桌抽屉 · 在手 1 件', action: () => {} }); MenuRow({ title: '露营箱', subtitle: '储物间 / 上层 · 整组记录', action: () => {} }); MenuRow({ title: '备用钥匙', subtitle: '玄关 / 小抽屉 · 常用', action: () => {} }); ActionButton({ label: '开始记录自己的物品', run: () => { this.stack.pop(); this.newItem(); }, primary: true }); }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12, bottom: 32 })
      }.width('100%').height('100%').align(Alignment.TopStart)
    }.title(name).onShown(()=>{const index=this.stack.getAllPathName().lastIndexOf(name);const id=this.stack.getParamByIndex(index) as string;if(name==='位置详情' && id)this.focusedLocation=id;if(name==='物品详情' && id)this.focusedId=id;}).backgroundColor($r('app.color.background')).onBackPressed(() => { if (name === '归档与回收站' || name === '搜索') { this.scope = 'CURRENT'; this.query = ''; this.search(); } return false; })
  }
  @Builder editor() { ItemEditor({ repository: this.repository, initial: this.editorDraft, onView:(id:string)=>{this.editorOpen=false;this.refresh();this.detail(id);}, onFind:(name:string)=>{this.editorOpen=false;this.query=name;this.scope='CURRENT';this.filter='全部';this.category='';this.submitSearch();this.navigate('搜索');}, onReminder:()=>{this.editorOpen=false;this.navigate('到期提醒');}, onSaved: (id: string) => { this.focusedId = id; this.refresh(); if (this.editorDraft.mode === 'EDIT' && id === this.editorDraft.itemId) { this.editorOpen = false; this.notify('已保存'); } }, onClose: () => { this.editorOpen = false; this.refresh(); } }) }
  @Builder tabLabel(label:string,index:number){Text(label).fontSize(15).fontColor(this.tab===index?$r('app.color.primary'):$r('app.color.secondary')).fontWeight(this.tab===index?FontWeight.Medium:FontWeight.Regular).height(48).constraintSize({minWidth:64}).textAlign(TextAlign.Center).backgroundColor(this.tab===index?$r('app.color.subtle'):Color.Transparent).borderRadius(24)}
  @Builder captureButton(){Button('+').fontSize(30).width(56).height(56).backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).accessibilityText('记下一件').onClick(()=>this.newItem())}
  build() {
    Navigation(this.stack) {
      Column() {
        Blank().width(0).height(0).bindSheet($$this.editorOpen, this.editor, { height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: $r('app.color.background'), keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY, onDisappear: () => this.resumeEntry() })
        Blank().width(0).height(0).bindSheet($$this.panelOpen, this.actionPanel, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: true, backgroundColor: $r('app.color.background'), keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL, onDisappear: () => this.resumeEntry() })
        Blank().width(0).height(0).bindSheet($$this.shareOpen, this.share, { height: SheetSize.LARGE, showClose: false, onDisappear: () => this.resumeEntry() })
        if (!this.ready) { LoadingProgress().width(48).height(48); Text(this.failure || '正在打开自己的家当').fontColor($r('app.color.text')); if (this.failure) { ActionButton({ label: '重新读取', run: () => this.open() }) } }
        else {
          HdsTabs({index:this.tab,controller:this.tabsController}) {
            TabContent(){Scroll(this.homeScroller){Column({space:12}){this.home()}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(0,this.homeScroller))}.tabBar(this.tabLabel('家当',0))
            TabContent(){Scroll(this.locationScroller){Column({space:12}){this.locations(true)}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(1,this.locationScroller))}.tabBar(this.tabLabel('位置',1))
            TabContent(){Scroll(this.mineScroller){Column({space:12}){this.mine()}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(2,this.mineScroller))}.tabBar(this.tabLabel('我的',2))
          }.barPosition(BarPosition.End).vertical(false).barOverlap(true).scrollable(false).animationDuration(this.data.preference.motion==='SIMPLE'?100:200)
          .barFloatingStyle({barWidth:{smallWidth:236,mediumWidth:300,largeWidth:360},barSideMargin:20,barBottomMargin:12,systemMaterialEffect:{materialType:hdsMaterial.MaterialType.IMMERSIVE,materialLevel:hdsMaterial.MaterialLevel.ADAPTIVE},miniBar:{miniBarBuilder:()=>{this.captureButton()},miniBarWidth:{smallWidth:56,mediumWidth:56,largeWidth:56}}})
          .onChange((index:number)=>{this.tab=index;this.preference((pref:Preference)=>pref.lastTab=index);}).width('100%').layoutWeight(1).onAreaChange((oldArea:Area,newArea:Area)=>this.contentWidth=Number(newArea.width))
        }
      }.width('100%').height('100%').backgroundColor($r('app.color.background'))
    }.hideTitleBar(true).mode(NavigationMode.Auto).navBarWidth(360).navBarWidthRange([320, 480]).minContentWidth(360).navDestination(this.destination).backgroundColor($r('app.color.background'))
  }
}
