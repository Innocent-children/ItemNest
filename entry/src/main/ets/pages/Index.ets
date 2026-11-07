import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { ActionButton, SectionHeading, MenuRow, GroupCard, QuickAction, StatTile, Segmented, StatusTag } from '../components/Common';
import { common, ConfigurationConstant, abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { Item, Draft, ItemDate, Location, Snapshot, Preference, ChangeEvent, copy, uuid, displayName, statusText, localDate, setDate, shortDate, relativeDue, daysUntil, friendlyTime, firstGlyph, dateTypeName, reminderClock, CATEGORY_CODES, CATEGORY_NAMES } from '../model/Models';
import { LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
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
import { readApplicationIcon } from '../services/ApplicationIcon';

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
  @State @Watch('search') homeFilter: string = '全部';
  @State @Watch('search') homeCategory: string = '';
  @State homeResults: Item[] = [];
  @State locationResults: Item[] = [];
  @State listView: boolean = false;
  @State query: string = '';
  @State scope: string = 'CURRENT';
  @State results: Item[] = [];
  @State selected: string[] = [];
  @State selecting: boolean = false;
  @State editorOpen: boolean = false;
  @State editorDraft: Draft = new Draft();
  @State focusedId: string = '';
  @State @Watch('search') focusedLocation: string = '';
  @State @Watch('search') includeChildren: boolean = true;
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
  @State activeIcon: string = '';
  @LocalStorageProp('launchIcon') launchIcon: string = '';
  @State iconReady: boolean = false;
  @State iconBusy: boolean = false;
  @State iconError: string = '';
  private iconRequest: number = 0;
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
  private async scan(openResult: boolean = false): Promise<void> {
    if (this.scanning) return; this.scanning = true;
    try {
      if(!scanCore.isDefaultScanSupported())throw new Error('设备暂不支持系统扫码');
      const result = await scanBarcode.startScanForResult(this.getUIContext().getHostContext() as common.UIAbilityContext, { scanTypes: [scanCore.ScanType.EAN13_CODE, scanCore.ScanType.EAN8_CODE, scanCore.ScanType.UPC_A_CODE, scanCore.ScanType.UPC_E_CODE, scanCore.ScanType.CODE128_CODE, scanCore.ScanType.QR_CODE] });
      const types: number[] = [scanCore.ScanType.EAN13_CODE, scanCore.ScanType.EAN8_CODE, scanCore.ScanType.UPC_A_CODE, scanCore.ScanType.UPC_E_CODE, scanCore.ScanType.CODE128_CODE, scanCore.ScanType.QR_CODE];
      this.barcodeType = ['EAN13','EAN8','UPC_A','UPC_E','CODE128','QR'][types.indexOf(result.scanType)]; this.barcode = result.originalValue;
      if (!this.barcodeType || !this.barcode || this.barcode.length>256) throw new Error('请选择有效商品条码');
      if (openResult) this.navigate('扫码查同款');
    } catch (error) {
      if ((error as BusinessError).code !== 1000500002) this.notify('暂时无法扫码，请重试；也可以在搜索中手动输入条码。');
    } finally { this.scanning = false; }
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
    Row() { Text('外部提醒显示物品名称').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.data.preference.externalDetails }).selectedColor($r('app.color.primary')).onChange((value: boolean) => this.preference((pref: Preference) => pref.externalDetails = value)); }.width('100%')
    ForEach(this.reminderResults,(result:ReminderResult)=>{Text(result.message).fontSize(15).fontColor($r('app.color.secondary'));},(result:ReminderResult)=>result.day+result.state+result.message)
  }
  @Builder voice() { VoicePanel({target:'搜索词',currentValue:this.query,maxLength:100,onAdopt:(value:string)=>{this.query=value;this.voiceOpen=false;this.submitSearch();},onCancel:()=>this.voiceOpen=false}) }

  aboutToAppear(): void {
    this.activeIcon = this.launchIcon;
    this.iconReady = !!this.activeIcon;
    this.fontScale = (this.getUIContext().getHostContext() as common.UIAbilityContext).config.fontSizeScale ?? 1;
    this.open();
  }
  aboutToDisappear():void {clearTimeout(this.queryTimer);clearTimeout(this.cardTimer);this.tabsController.unbindScroller(this.homeScroller);this.tabsController.unbindScroller(this.locationScroller);this.tabsController.unbindScroller(this.mineScroller);}
  private async open(): Promise<void> {
    this.failure = '';
    if (!this.iconReady) this.loadIcon();
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
  private foreground(): void { if (this.ready) { this.repository.reload(); this.repository.maintain(this.getUIContext().getHostContext() as common.UIAbilityContext); this.refresh(); this.readShares(); if (!this.iconBusy) this.loadIcon(); } }
  private routeEntry(): void {
    if (!this.ready || !this.entryAction) return;
    const action = this.entryAction; AppStorage.set('entryAction', '');
    if (this.editorOpen || this.shareOpen || this.panelOpen || this.voiceOpen) {
      this.pendingAction = action; this.pendingItemId = AppStorage.get<string>('entryItemId') ?? '';
      this.notify('入口已保留，完成当前操作后继续'); return;
    }
    if (action === 'capture') this.newItem();
    else if (action === 'search') this.beginSearch();
    else if (action === 'dates') this.navigate('提醒');
    else if (action === 'cardSettings') this.navigate('外观与隐私');
    else if (action === 'scan') this.scan(true);
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
  private selectedCardIds(): string[] {
    return this.data.preference.cardIds.filter((value: string) => this.data.items.some((item: Item) => item.id === value && !item.deletedAt && item.status !== 'ARCHIVED'));
  }
  private selectCardItem(id: string, selected: boolean): void {
    const ids = this.selectedCardIds();
    if (selected && !ids.includes(id) && ids.length >= 3) { this.notify('最多选择 3 条'); return; }
    this.preference((pref: Preference) => pref.cardIds = selected ? (ids.includes(id) ? ids : [...ids, id]) : ids.filter((value: string) => value !== id));
  }
  private notify(message: string): void { this.getUIContext().getPromptAction().showToast({ message, duration: 3000 }); }
  private act(run: () => void, message: string = '已保存'): void { try { run(); this.refresh(); if (message) this.notify(message); } catch (error) { this.notify((error as Error).message); } }
  private navigate(name: string): void { this.endSelection(); this.stack.pushPath({ name, param: name==='位置详情'?this.focusedLocation:name==='物品详情'?this.focusedId:'' }); }
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
  private search(): void {
    if (!this.ready && !this.repository.data.items.length) return;
    this.results = this.repository.search(this.query, this.scope, this.filter, this.category);
    this.homeResults = this.repository.search('', 'CURRENT', this.homeFilter, this.homeCategory);
    this.locationResults = this.repository.search('', 'CURRENT', '', '', this.focusedLocation, this.includeChildren);
  }
  private homeItems(): Item[] { return this.homeResults; }
  private locationItems(): Item[] { return this.locationResults; }
  private endSelection(): void { this.selecting = false; this.selected = []; }
  private selectItem(id: string): void {
    const pages = this.stack.getAllPathName();
    const page = pages[pages.length - 1] ?? '';
    if (!page || page === '位置详情' || (page === '搜索' && (!!this.query.trim() || this.filter !== '全部' || !!this.category))) {
      this.selecting = true; this.selected = [id];
    }
  }
  private beginSearch(): void {
    clearTimeout(this.queryTimer);
    this.query = ''; this.scope = 'CURRENT'; this.filter = '全部'; this.category = ''; this.searchFilters = false;
    this.search(); this.navigate('搜索');
  }
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
    Column({ space: 14 }) { this.characterImage(150); Text(title).fontSize(23).fontColor($r('app.color.text')); Text(subtitle).fontSize(15).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center) }.width('100%').padding({ top: 28, bottom: 24 })
  }
  @Builder characterImage(size: number) {
    if (this.activeIcon) {
      Image(this.activeIcon === 'moving_buddy' ? $r('app.media.buddy_foreground') : $r('app.media.foreground'))
        .width(size).height(size).objectFit(ImageFit.Contain).syncLoad(true)
    } else {
      Blank().width(size).height(size).flexGrow(0)
    }
  }
  // 整组和已选分类用系统图标表示，其余记录用名称首字，让没有照片的记录也容易分辨。
  private kindIcon(item: Item): Resource | undefined {
    if (item.kind === 'GROUP') return $r('sys.symbol.square_stack_3d');
    if (item.category === 'DIGITAL') return $r('sys.symbol.headphones');
    if (item.category === 'CLOTHING') return $r('sys.symbol.shirt');
    if (item.category === 'HOME') return $r('sys.symbol.sofa_fill');
    if (item.category === 'FOOD') return $r('sys.symbol.fork_knife');
    if (item.category === 'TOOLS') return $r('sys.symbol.wrench_and_screwdriver');
    if (item.category === 'DOCUMENTS') return $r('sys.symbol.doc_text');
    return undefined;
  }
  @Builder glyphMark(item: Item, size: number) {
    if (this.kindIcon(item)) { SymbolGlyph(this.kindIcon(item)).fontSize(size * 0.44).fontColor([$r('app.color.primary')]) }
    else { Text(firstGlyph(item)).fontSize(size * 0.4).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary')) }
  }
  @Builder glyph(item: Item, size: number) {
    Stack() { this.glyphMark(item, size) }.width(size).height(size).backgroundColor($r('app.color.subtle')).borderRadius(Math.min(18, size * 0.28))
  }
  // 最近一个未处理日期距今的天数；没有日期时返回一个很大的数
  private dueDays(item: Item): number {
    const days = item.dates.filter((date: ItemDate) => !date.handledAt).map((date: ItemDate) => daysUntil(date.date));
    return days.length ? Math.min(...days) : 9999;
  }
  // 列表与网格共用的状态标签：只显示和“在手 1 件”不同的情况，减少每张卡片上的重复文字
  @Builder statusTags(item: Item) {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
      if (item.deletedAt) { StatusTag({ label: '回收站', warning: true }) }
      else if (item.status === 'LENT') { StatusTag({ label: '借给' + item.borrower }) }
      else if (item.status === 'ARCHIVED') { StatusTag({ label: statusText(item) }) }
      if (item.kind === 'GROUP') { StatusTag({ label: '整组' }) }
      else if ((item.quantity ?? 0) > 1 && item.status !== 'ARCHIVED') { StatusTag({ label: `${item.quantity} 件` }) }
      if (this.dueBadge(item)) { StatusTag({ label: this.dueBadge(item), warning: this.dueDays(item) <= 7 }) }
    }.width('100%')
  }
  @Builder itemRow(item: Item, here: string) {
    Row({ space: 12 }) {
      if (this.selecting) { Checkbox({ name: item.id }).select(this.selected.includes(item.id)).accessibilityText('选择' + displayName(item)).onChange((selected: boolean) => { this.selected = selected ? Array.from(new Set([...this.selected, item.id])) : this.selected.filter((id: string) => id !== item.id); }) }
      if (item.photoIds.length) { Image(this.media().uri(item.photoIds[0], true)).width(60).height(60).objectFit(ImageFit.Cover).borderRadius(16).accessibilityText(displayName(item) + '主图') }
      else { this.glyph(item, 60) }
      Column({ space: 5 }) {
        Row({ space: 6 }) {
          Text(displayName(item)).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
          if (item.favorite) { SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor([$r('app.color.star')]) }
        }
        if (!here || item.locationId !== here) { Text(this.repository.path(item.locationId) || '位置待补充').fontSize(13).fontColor($r('app.color.secondary')) }
        if (this.matchText(item)) { Text(this.matchText(item)).fontSize(13).fontColor($r('app.color.secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
        this.statusTags(item)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(12).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(() => this.selecting ? this.toggle(item.id) : this.detail(item.id)).gesture(LongPressGesture().onAction(() => this.selectItem(item.id)))
  }
  @Builder items($$: ItemRows) {
    ForEach($$.values.slice(0, this.pageSize), (item: Item) => this.itemRow(item, $$.here ?? ''), (item: Item) => item.id + ':' + item.revision)
    if($$.values.length>this.pageSize){ActionButton({ label: `继续显示（已显示 ${this.pageSize} / ${$$.values.length}）`, run: ()=>this.pageSize+=60 })}
  }
  @Builder filters(home: boolean = false) {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(['全部', '常用', '借出', '整组', '待补位置'], (name: string) => { ActionButton({ label: name, tonal: (home ? this.homeFilter : this.filter) === name, run: () => { this.endSelection(); if (home) this.homeFilter = name; else this.filter = name; this.search(); } }) })
        Select(CATEGORY_NAMES.map((name: string, index: number): SelectOption => ({ value: index ? name : '全部分类' }))).value((home ? this.homeCategory : this.category) ? CATEGORY_NAMES[CATEGORY_CODES.indexOf(home ? this.homeCategory : this.category)] : '全部分类').font({ size: 15 }).fontColor($r('app.color.primary')).backgroundColor($r('app.color.surface')).height(48).onSelect((index: number) => { this.endSelection(); if (home) this.homeCategory = CATEGORY_CODES[index]; else this.category = CATEGORY_CODES[index]; this.search(); })
        if ((home ? this.homeCategory : this.category) || (home ? this.homeFilter : this.filter) !== '全部') { ActionButton({ label: '清除', run: () => { this.endSelection(); if (home) { this.homeFilter = '全部'; this.homeCategory = ''; } else { this.filter = '全部'; this.category = ''; } this.search(); } }) }
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
  }
  @Builder batch(values: Item[]) {
    if (this.selecting) {
      Row({ space: 8 }) { Text(`已选 ${this.selected.length} 条`).layoutWeight(1).fontColor($r('app.color.text')); ActionButton({ label: '全选', run: () => this.selected = values.map((item: Item) => item.id) }); ActionButton({ label: '完成', run: () => this.endSelection() }) }
      Row({ space: 8 }) {
        ActionButton({ label: '移位置', run: () => this.openPanel('批量移位置') })
        ActionButton({ label: '移入回收站', run: () => this.confirm('移入回收站', `将 ${this.selected.length} 条记录移入回收站，保留 30 天。`, () => { this.repository.recycle(this.selected); this.selected = []; this.selecting = false; }) })
      }.enabled(this.selected.length > 0)
    }
  }
  @Builder home() {
    Row() {
      Column({ space: 2 }) {
        Text('我的家当').fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
        Text('在这里，物品井井有条').fontSize(14).fontColor($r('app.color.secondary'))
      }.alignItems(HorizontalAlign.Start)
      Blank()
    }.width('100%').padding({ top: 12 })
    Row({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([$r('app.color.secondary')])
        Text('找东西：名称、拼音、说明或位置').fontSize(16).fontColor($r('app.color.secondary')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).height(52).accessibilityText('找东西').accessibilityLevel('yes').onClick(() => this.beginSearch())
      Stack() { SymbolGlyph($r('sys.symbol.barcode_viewfinder')).fontSize(22).fontColor([$r('app.color.primary')]) }
        .width(48).height(48).borderRadius(24).accessibilityText('扫一扫，看看是否记过').accessibilityLevel('yes')
        .onClick(() => this.scan(true))
    }
      .width('100%').height(52).padding({ left: 18, right: 4 }).backgroundColor($r('app.color.surface')).borderRadius(26)
    if (this.upcoming().length) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.bell')).fontSize(18).fontColor([$r('app.color.warning')])
          Text(this.upcoming().some((row: DateRow) => daysUntil(row.date.date) < 0) ? '有日期需要处理' : '快到期了').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.warning'))
          Blank()
          Text(`${this.upcoming().length} 项`).fontSize(14).fontColor($r('app.color.secondary'))
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.tertiary')])
        }.width('100%')
        ForEach(this.upcoming().slice(0, 3), (row: DateRow) => {
          Row() { Text(displayName(row.item)).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(relativeDue(row.date.date, row.date.type)).fontSize(14).fontColor(daysUntil(row.date.date) <= 2 ? $r('app.color.warning') : $r('app.color.secondary')) }.width('100%').padding({ left: 26 })
        }, (row: DateRow) => row.date.id + ':' + row.date.date)
      }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(() => this.navigate('提醒')).accessibilityLevel('yes')
    }
    if (this.latestDraft()) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([$r('app.color.primary')])
        Text('继续刚才的记录：' + displayName((this.latestDraft() ?? new Draft()).payload)).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.tertiary')])
      }.width('100%').padding({ left: 16, right: 14, top: 13, bottom: 13 }).backgroundColor($r('app.color.subtle')).borderRadius(16).onClick(() => { const draft = this.latestDraft(); if (draft) this.resume(draft); })
    }
    if (this.data.items.some((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED')) {
      this.filters(true)
      Row() {
        Text(`${this.homeFilter}${this.homeCategory ? ' · ' + CATEGORY_NAMES[CATEGORY_CODES.indexOf(this.homeCategory)] : ''} · ${this.homeItems().length} 条`).fontSize(14).fontColor($r('app.color.secondary')).layoutWeight(1)
        ActionButton({ label: this.listView ? '看照片' : '看列表', run: () => this.listView = !this.listView })
      }.width('100%')
      this.batch(this.homeItems())
    }
    if (!this.homeItems().length) {
      if (this.homeFilter !== '全部' || this.homeCategory) {
        Text('这里还没有对应记录').fontSize(20).fontColor($r('app.color.text'))
        Text('可以换个筛选条件，或查看全部家当。').fontSize(15).fontColor($r('app.color.secondary'))
      } else { this.empty('记住放哪，用好已有', '先记一件你以后会找的东西') }
      ActionButton({ label: '记下一件', icon: $r('sys.symbol.plus'), run: () => this.newItem(), primary: true })
      if (this.homeFilter !== '全部' || this.homeCategory) { ActionButton({ label: '查看全部', run: () => { this.homeFilter = '全部'; this.homeCategory = ''; this.endSelection(); } }) }
      else { ActionButton({ label: '看看示例', run: () => { this.example = true; this.navigate('示例家当'); } }) }
    } else { this.homeGrid() }
  }
  @Builder gridCard(item: Item) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (item.photoIds.length) { Image(this.media().uri(item.photoIds[0], true)).width('100%').height('100%').objectFit(ImageFit.Cover).accessibilityText(displayName(item) + '主图') }
        else { Stack() { this.glyphMark(item, 64) }.width('100%').height('100%').backgroundColor($r('app.color.subtle')) }
        if (this.selecting) { Checkbox({ name: 'grid' + item.id }).select(this.selected.includes(item.id)).hitTestBehavior(HitTestMode.None).margin(8) }
        else if (item.favorite) { Stack() { SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor([$r('app.color.star')]) }.width(28).height(28).borderRadius(14).backgroundColor($r('app.color.surface')).margin(8) }
      }.width('100%').aspectRatio(1.5).clip(true)
      Column({ space: 4 }) {
        Text(displayName(item)).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.repository.path(item.locationId) || '位置待补充').fontSize(12).fontColor($r('app.color.secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        this.statusTags(item)
      }.alignItems(HorizontalAlign.Start).padding({ left: 12, right: 12, top: 10, bottom: 12 }).width('100%').constraintSize({ minHeight: 96 })
    }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20).clip(true)
    .accessibilityGroup(true).accessibilityText(displayName(item) + '，' + (this.repository.path(item.locationId) || '位置待补充') + '，' + statusText(item))
    .onClick(() => this.selecting ? this.toggle(item.id) : this.detail(item.id)).gesture(LongPressGesture().onAction(() => { this.selecting = true; this.selected = [item.id]; }))
  }
  @Builder homeGrid(){
    if(this.listView || this.contentWidth<360 || this.fontScale>1.3){this.items({ values: this.homeItems() })}else{
      GridRow({columns:this.contentWidth>=600?3:2,gutter:12}){
        ForEach(this.homeItems().slice(0,this.pageSize),(item:Item)=>{
          GridCol(){ this.gridCard(item) }
        },(item:Item)=>item.id+':'+item.revision+':'+this.selecting)
      }.width('100%')
      if(this.homeItems().length>this.pageSize){ActionButton({label:'继续显示更多',run:()=>this.pageSize+=60})}
    }
  }
  @Builder searchPage() {
    if (this.voiceOpen) { this.voice() }
    Search({ value: this.query, placeholder: '名称、拼音、说明、位置' }).id('searchInput').height(52).maxLength(100).defaultFocus(true)
      .onAppear(() => setTimeout(() => { try { this.getUIContext().getFocusController().requestFocus('searchInput'); } catch (_) {} }, 350)).onChange((value: string, preview: PreviewText) => { this.endSelection(); this.query = value; clearTimeout(this.queryTimer); if (!preview.value) this.queryTimer = setTimeout(() => this.search(), 200); }).onSubmit(() => this.submitSearch())
    Row({space:8}) {ActionButton({ label: '扫一扫', icon: $r('sys.symbol.barcode_viewfinder'), tonal: true, run: ()=>this.navigate('扫码查同款') });ActionButton({ label: '语音', icon: $r('sys.symbol.mic'), tonal: true, run: ()=>this.voiceOpen=true });ActionButton({label: this.searchFilters ? '收起筛选' : (this.category || this.filter !== '全部' || this.scope !== 'CURRENT' ? '筛选 · 已选' : '筛选'), tonal: this.searchFilters, run:()=>this.searchFilters=!this.searchFilters});}
    if (this.searchFilters) {
    Row({ space: 8 }) { ActionButton({ label: this.scope === 'CURRENT' ? '✓ 在手与借出' : '在手与借出', run: () => { this.endSelection(); this.scope = 'CURRENT'; this.search(); } }); ActionButton({ label: this.scope === 'ARCHIVED' ? '✓ 归档' : '归档', run: () => { this.endSelection(); this.scope = 'ARCHIVED'; this.search(); } }) }
    this.filters()
    }
    if (this.query.trim() || this.filter !== '全部' || this.category) {
      Text(`${this.scope === 'ARCHIVED' ? '归档' : '在手与借出'} · ${this.filter}${this.category ? ' · ' + CATEGORY_NAMES[CATEGORY_CODES.indexOf(this.category)] : ''} · ${this.results.length} 条`).fontSize(14).fontColor($r('app.color.secondary'))
    }
    this.batch(this.results)
    if (!this.query.trim() && this.filter === '全部' && !this.category) {
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
  private childLocations(parentId: string): Location[] { return this.data.locations.filter((location: Location) => location.parentId === parentId).sort((a: Location, b: Location) => a.sortOrder - b.sortOrder); }
  @Builder locations(root: boolean = false) {
    if (root) SectionHeading({ title: '位置', subtitle: '按存放位置，找到你的物品' })
    if (this.childLocations(root ? '' : this.focusedLocation).length) {
      GroupCard({ header: root ? '' : '里面的位置' }) {
        ForEach(this.childLocations(root ? '' : this.focusedLocation), (location: Location, index: number) => {
          MenuRow({ plain: true, first: index === 0, icon: root ? $r('sys.symbol.house') : $r('sys.symbol.folder'), title: location.name, subtitle: `${this.repository.search('', 'CURRENT', '', '', location.id).length} 条记录` + (this.data.locations.some((node: Location) => node.parentId === location.id) ? ` · ${this.data.locations.filter((node: Location) => node.parentId === location.id).length} 个子位置` : ''), action: () => { this.focusedLocation = location.id; this.navigate('位置详情'); } })
        }, (location: Location) => location.id + ':' + location.revision)
      }
    } else if (root) {
      Text('先建一个最常放东西的地方，比如“书桌抽屉”“玄关柜”。记录时也可以随手新建。').fontSize(15).fontColor($r('app.color.secondary'))
    }
    ActionButton({ label: root ? '新建位置' : '新建子位置', icon: $r('sys.symbol.plus'), tonal: true, run: () => { if (root) this.focusedLocation = ''; this.openLocationForm(); } })
  }
  @Builder locationDetail() {
    SectionHeading({ title: this.location().name, subtitle: this.location().parentId ? '在 ' + this.repository.path(this.location().parentId) : '' })
    if(this.location().photoAssetId){Image(this.media().uri(this.location().photoAssetId)).width('100%').aspectRatio(1.5).objectFit(ImageFit.Cover).borderRadius(20).onClick(()=>this.openPhoto([this.location().photoAssetId],this.location().photoAssetId))}
    if (this.location().notes) { Text(this.location().notes).fontColor($r('app.color.secondary')) }
    Row({ space: 8 }) { ActionButton({ label: '在这里记下', icon: $r('sys.symbol.plus'), run: () => this.newItem(this.focusedLocation), primary: true }); ActionButton({ label: '编辑位置', icon: $r('sys.symbol.square_and_pencil'), tonal: true, run: () => this.openLocationForm(true) }); }
    this.locations()
    if (this.data.locations.some((node: Location) => node.parentId === this.focusedLocation)) {
      Segmented({ options: ['包含子位置', '只看这一层'], selected: this.includeChildren ? 0 : 1, onSelect: (index: number) => { this.endSelection(); this.includeChildren = index === 0; } })
    }
    Text(`${this.includeChildren ? '包含子位置' : '只看这一层'} · ${this.locationItems().length} 条记录`).fontSize(14).fontColor($r('app.color.secondary'))
    this.batch(this.locationItems())
    this.items({ values: this.locationItems(), here: this.focusedLocation })
    ActionButton({ label: '移除这个位置', icon: $r('sys.symbol.trash'), danger: true, run: () => this.openPanel('移除位置') })
  }
  private confirmFound(): void { this.act(() => this.repository.mutate([this.focusedId], '确认位置', (item: Item) => item.locationConfirmedAt = Date.now()), '位置已确认'); }
  private toggleFavorite(): void { const on = !this.current().favorite; this.act(() => this.repository.mutate([this.focusedId], '修改常用', (item: Item) => item.favorite = on), on ? '已设为常用' : '已取消常用'); }
  private locationSubtitle(item: Item): string {
    const path = this.repository.path(item.locationId) || '位置待补充';
    if (item.status !== 'ACTIVE' || item.deletedAt || !item.locationId) return path;
    return path + '\n' + (item.locationConfirmedAt ? '上次确认在这里：' + friendlyTime(item.locationConfirmedAt) : '找到实物后点“找到了”，下次更放心');
  }
  @Builder details() {
    if (!this.data.items.some((item: Item) => item.id === this.focusedId)) { this.empty('这条记录已移除', '返回家当查看其他记录') }
    else {
      if (this.current().photoIds.length) {
        Swiper() { ForEach(this.current().photoIds, (id: string) => { Image(this.media().uri(id)).width('100%').height('100%').objectFit(ImageFit.Cover).onClick(() => this.openPhoto(this.current().photoIds, id)) }, (id: string) => id) }
          .width('100%').aspectRatio(4 / 3).borderRadius(24).clip(true).loop(false).indicator(this.current().photoIds.length > 1)
      }
      Row({ space: 14 }) {
        if (!this.current().photoIds.length) { this.glyph(this.current(), 60) }
        Column({ space: 8 }) {
          Text(displayName(this.current())).fontSize(26).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
            StatusTag({ label: statusText(this.current()), warning: !!this.current().deletedAt })
            if (this.dueBadge(this.current())) { StatusTag({ label: this.dueBadge(this.current()), warning: this.dueDays(this.current()) <= 7 }) }
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (!this.current().deletedAt && this.current().status !== 'ARCHIVED') {
          Stack() { SymbolGlyph(this.current().favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star')).fontSize(24).fontColor([this.current().favorite ? $r('app.color.star') : $r('app.color.secondary')]) }
            .width(48).height(48).borderRadius(24).onClick(() => this.toggleFavorite())
            .accessibilityText(this.current().favorite ? '取消常用' : '设为常用').accessibilityLevel('yes')
        }
      }.width('100%').alignItems(VerticalAlign.Top).padding({ top: 4 })
      if (!this.current().deletedAt && this.current().status !== 'ARCHIVED') {
        Row() {
          if (this.current().status === 'ACTIVE' && this.current().locationId) { QuickAction({ label: '找到了', icon: $r('sys.symbol.checkmark_circle'), run: () => this.confirmFound() }) }
          QuickAction({ label: this.current().locationId ? '改位置' : '补位置', icon: this.current().locationId ? $r('sys.symbol.arrow_left_arrow_right') : $r('sys.symbol.mappin_and_rectangle'), accent: !this.current().locationId && this.current().status === 'ACTIVE', run: () => this.openPanel('改位置') })
          if (this.current().status === 'LENT') { QuickAction({ label: '已归还', icon: $r('sys.symbol.arrowshape_turn_up_left'), accent: true, run: () => this.openPanel('已归还') }) }
          else { QuickAction({ label: '借出', icon: $r('sys.symbol.arrowshape_turn_up_right'), run: () => this.openPanel('借出') }) }
          QuickAction({ label: '编辑', icon: $r('sys.symbol.square_and_pencil'), run: () => this.edit(this.current()) })
        }.width('100%')
      }
      GroupCard() {
        MenuRow({ plain: true, first: true, icon: $r('sys.symbol.mappin_and_rectangle'), title: this.current().status === 'LENT' ? '归还时放回' : this.current().deletedAt ? '回收时的位置' : '放在这里', subtitle: this.current().deletedAt ? (this.current().previousLocationPath || '位置待补充') : this.locationSubtitle(this.current()), chevron: !this.current().deletedAt, action: () => { if (!this.current().deletedAt) this.openPanel('改位置'); } })
        ForEach(this.current().dates, (date: ItemDate) => { MenuRow({ plain: true, icon: date.type === 'RETURN' ? $r('sys.symbol.arrowshape_turn_up_left') : $r('sys.symbol.calendar'), title: date.handledAt ? dateTypeName(date.type) + ' · ' + shortDate(date.date) : relativeDue(date.date, date.type) + '（' + shortDate(date.date) + '）', subtitle: date.handledAt ? '已处理' : this.dateArrangement(date), action: () => this.navigate('提醒') }) }, (date: ItemDate) => date.id + ':' + date.dateVersion + ':' + date.handledAt)
        if (this.current().sourceItemId) { MenuRow({ plain: true, icon: $r('sys.symbol.rectangle_on_rectangle'), title: '从原记录拆出', subtitle: this.data.items.find((item: Item) => item.id === this.current().sourceItemId)?.title || '查看来源记录', action: () => { const source = this.data.items.find((item: Item) => item.id === this.current().sourceItemId); if (source) this.detail(source.id); else this.notify('来源记录已移除，拆分历史仍保留'); } }) }
        if (this.current().missingPhotoCount) { MenuRow({ plain: true, icon: $r('sys.symbol.picture'), title: `${this.current().missingPhotoCount} 张原照片待补充`, subtitle: '可在编辑中重新添加', action: () => this.edit(this.current()) }) }
      }
      if (this.current().notes || this.current().aliases.length || this.current().tags.length || this.current().barcodeValue) {
        Column({ space: 8 }) {
          if (this.current().notes) { Text(this.current().notes).fontSize(16).fontColor($r('app.color.text')).copyOption(CopyOptions.InApp).width('100%') }
          if (this.current().aliases.length) { Text('也叫：' + this.current().aliases.join('、')).fontSize(14).fontColor($r('app.color.secondary')) }
          if (this.current().tags.length) { Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) { ForEach(this.current().tags, (tag: string) => { StatusTag({ label: '# ' + tag }) }, (tag: string) => tag) } }
          if (this.current().barcodeValue) { Text('商品条码：' + this.current().barcodeValue).fontSize(13).fontColor($r('app.color.secondary')) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.surface')).borderRadius(20)
      }
      if (this.current().deletedAt) {
        Text('保留至 ' + friendlyTime(this.current().purgeAt)).fontColor($r('app.color.warning'))
        ActionButton({ label: '恢复记录', icon: $r('sys.symbol.arrow_counterclockwise'), run: () => this.openPanel('恢复记录'), primary: true })
        ActionButton({ label: '永久删除', icon: $r('sys.symbol.trash'), danger: true, run: () => this.confirm('永久删除', `删除“${displayName(this.current())}”及 ${this.repository.unreferencedPhotoCount(this.focusedId)} 张不再被其他记录引用的照片。此操作无法撤销。`, () => { this.repository.purge([this.focusedId]); this.stack.pop(); }) })
      } else if (this.current().status === 'ARCHIVED') { ActionButton({ label: '恢复到家当', icon: $r('sys.symbol.arrow_counterclockwise'), run: () => this.openPanel('恢复到家当'), primary: true }) }
      else {
        GroupCard({ header: '更多操作' }) {
          if (this.current().kind === 'SINGLE') { MenuRow({ plain: true, first: true, icon: $r('sys.symbol.list_number'), title: '调整数量', subtitle: '用掉一些，或又买了几件', value: `${this.current().quantity ?? 0} 件`, action: () => this.openPanel('调整数量') }) }
          if (this.current().kind === 'SINGLE' && (this.current().quantity ?? 0) > 1 && this.current().status === 'ACTIVE') { MenuRow({ plain: true, icon: $r('sys.symbol.rectangle_on_rectangle'), title: '拆分数量', subtitle: '例如只借出其中几件', action: () => this.openPanel('拆分数量') }) }
          MenuRow({ plain: true, first: this.current().kind !== 'SINGLE', icon: $r('sys.symbol.plus_circle'), title: '在这里再记一件', subtitle: this.repository.path(this.current().locationId) || '同样先不选位置', action: () => this.newItem(this.current().locationId) })
          MenuRow({ plain: true, icon: $r('sys.symbol.archivebox'), title: '归档', subtitle: '用完、送出、出售或丢弃', action: () => this.openPanel('归档') })
          MenuRow({ plain: true, icon: $r('sys.symbol.trash'), title: '移入回收站', danger: true, chevron: false, action: () => this.confirm('移入回收站', '记录与照片保留 30 天，可从“我的 → 归档与回收站”恢复。', () => { this.repository.recycle([this.focusedId]); this.stack.pop(); }) })
        }
      }
      GroupCard() {
        MenuRow({ plain: true, first: true, icon: $r('sys.symbol.clock_arrow_2_circlepath'), title: '变化记录', value: this.historyOpen ? '收起' : `${this.data.events.filter((event: ChangeEvent) => event.itemId === this.focusedId).length} 条`, chevron: !this.historyOpen, action: () => this.historyOpen = !this.historyOpen })
        if (this.historyOpen) {
          ForEach(this.data.events.filter((event: ChangeEvent) => event.itemId === this.focusedId).sort((a: ChangeEvent, b: ChangeEvent) => b.createdAt - a.createdAt), (event: ChangeEvent) => {
            Column({ space: 4 }) { Text(event.type + ' · ' + friendlyTime(event.createdAt)).fontSize(14).fontColor($r('app.color.text')); ForEach(this.historyLines(event), (line: string) => { Text(line).fontSize(13).fontColor($r('app.color.secondary')) }, (line: string, index: number) => index + line) }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 56, right: 16, top: 6, bottom: 10 })
          }, (event: ChangeEvent) => event.id)
        }
      }
    }
  }
  private async loadIcon(): Promise<boolean> {
    const request = ++this.iconRequest;
    try {
      const icon = await readApplicationIcon();
      if (request !== this.iconRequest) return false;
      this.activeIcon = icon;
      this.iconReady = true; this.iconError = '';
      return true;
    } catch (_) {
      if (request === this.iconRequest) { this.iconReady = false; this.iconError = '暂时无法读取当前图标，请重试。'; }
      return false;
    }
  }
  private async chooseIcon(name: string): Promise<void> {
    if (this.iconBusy || !this.iconReady || this.activeIcon === name) return;
    this.iconBusy = true; this.iconError = ''; ++this.iconRequest;
    try {
      await bundleManager.setAlternateIcon(name);
      if (await this.loadIcon()) {
        if (this.activeIcon === name) this.notify('已切换为' + (name === 'moving_buddy' ? '男生版' : '女生版'));
        else this.iconError = '图标尚未切换，请再试一次。';
      }
    } catch (_) {
      this.iconError = '这次未能更换图标，请稍后重试。';
    } finally { this.iconBusy = false; }
  }
  @Builder iconChoice(name: string, label: string, picture: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        Image(picture).width(64).height(64).objectFit(ImageFit.Contain).accessibilityText(label + '图标预览')
        Column({ space: 5 }) {
          Text(label).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text(this.iconReady && this.activeIcon === name ? '正在使用' : '点击更换').fontSize(13).fontColor($r('app.color.secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.iconReady && this.activeIcon === name) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(24).fontColor([$r('app.color.primary')])
        }
      }.width('100%').padding(16)
    }.width('100%').backgroundColor(this.activeIcon === name && this.iconReady ? $r('app.color.subtle') : $r('app.color.surface'))
      .borderRadius(24)
      .enabled(this.iconReady && !this.iconBusy).accessibilityText(label).accessibilitySelected(this.activeIcon === name && this.iconReady)
      .onClick(() => this.chooseIcon(name))
  }
  @Builder iconPage() {
    Text('选一个你喜欢的形象').fontSize(24).fontColor($r('app.color.text'))
    Text('桌面上的“我的家当”和应用内的人物插图会使用你选择的形象。').fontSize(15).fontColor($r('app.color.secondary'))
    Column({ space: 12 }) {
      this.iconChoice('moving_girl', '女生版', $r('app.media.foreground'))
      this.iconChoice('moving_buddy', '男生版', $r('app.media.buddy_foreground'))
    }.width('100%')
    if (this.iconBusy) { Text('正在更换图标…').fontColor($r('app.color.secondary')) }
    else if (this.iconError) {
      Text(this.iconError).fontColor($r('app.color.danger'))
      ActionButton({ label: '重新读取', run: () => this.loadIcon() })
    } else if (!this.iconReady) { LoadingProgress().width(32).height(32) }
  }
  @Builder mine() {
    SectionHeading({ title: '我的', subtitle: '' })
    Row({ space: 8 }) {
      StatTile({ value: String(this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'SINGLE').length), label: '单件记录（条）' })
      StatTile({ value: String(this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.kind === 'GROUP').length), label: '整组记录（组）' })
      StatTile({ value: String(this.data.items.filter((item: Item) => !item.deletedAt && item.status === 'ACTIVE' && item.kind === 'SINGLE').reduce((sum: number, item: Item) => sum + (item.quantity ?? 0), 0)), label: '在手单件（件）' })
    }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 16 }).backgroundColor($r('app.color.surface')).borderRadius(20)
    GroupCard() {
      MenuRow({ plain: true, first: true, icon: $r('sys.symbol.star'), title: '常用', subtitle: '常找的物品放在手边', value: String(this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED' && item.favorite).length), action: () => { this.endSelection(); this.tab = 0; this.homeFilter = '常用'; this.homeCategory = ''; } })
      MenuRow({ plain: true, icon: $r('sys.symbol.square_and_pencil'), title: '草稿', subtitle: this.data.drafts.length ? '还没保存的记录' : '没有未完成的记录', value: this.data.drafts.length ? String(this.data.drafts.length) : '', action: () => this.navigate('草稿') })
      MenuRow({ plain: true, icon: $r('sys.symbol.bell'), title: '提醒', subtitle: this.upcoming().length ? `${this.upcoming().length} 项 30 天内到期或已过期` : '到期、保修、归还日期', action: () => this.navigate('提醒') })
    }
    GroupCard() {
      MenuRow({ plain: true, first: true, icon: $r('sys.symbol.archivebox'), title: '归档与回收站', subtitle: '查看历史，恢复记录', action: () => { this.scope = 'ARCHIVED'; this.query = ''; this.filter = '全部'; this.category = ''; this.search(); this.navigate('归档与回收站'); } })
      MenuRow({ plain: true, icon: $r('sys.symbol.externaldrive'), title: '数据管理', subtitle: this.data.preference.lastBackupAt ? '最近备份：' + friendlyTime(this.data.preference.lastBackupAt) : '还没有备份，建议做一份完整备份', action: () => this.navigate('数据管理') })
    }
    GroupCard() {
      MenuRow({ plain: true, first: true, icon: $r('sys.symbol.paintpalette'), title: '外观与隐私', subtitle: '主题、动效、卡片与权限', action: () => this.navigate('外观与隐私') })
      MenuRow({ plain: true, icon: $r('sys.symbol.person'), title: '应用图标', subtitle: '选择喜欢的男生版或女生版', value: this.iconReady ? (this.activeIcon === 'moving_buddy' ? '男生版' : '女生版') : '', action: () => { this.loadIcon(); this.navigate('应用图标'); } })
      MenuRow({ plain: true, icon: $r('sys.symbol.questionmark_circle'), title: '帮助与关于', subtitle: '怎样记录，怎样长期保存', action: () => this.navigate('帮助与关于') })
    }
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
  @Builder toggleRow(title: string, subtitle: string, isOn: boolean, first: boolean, change: (value: boolean) => void) {
    Column() {
      if (!first) { Divider().strokeWidth(0.5).color($r('app.color.outline')).margin({ left: 16 }) }
      Row({ space: 12 }) {
        Column({ space: 4 }) { Text(title).fontSize(17).fontColor($r('app.color.text')); if (subtitle) { Text(subtitle).fontSize(13).fontColor($r('app.color.secondary')) } }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: isOn }).selectedColor($r('app.color.primary')).onChange((value: boolean) => change(value))
      }.width('100%').padding({ left: 16, right: 12, top: 12, bottom: 12 }).constraintSize({ minHeight: 56 })
    }.width('100%')
  }
  @Builder settings() {
    GroupCard({ header: '主题' }) {
      Column() { Segmented({ options: ['跟随系统', '浅色', '深色'], selected: ['SYSTEM', 'LIGHT', 'DARK'].indexOf(this.data.preference.theme), onSelect: (index: number) => this.preference((pref: Preference) => pref.theme = ['SYSTEM', 'LIGHT', 'DARK'][index]) }) }.padding(12)
      MenuRow({ plain: true, title: '动效表现', subtitle: '简洁时减少页面切换动画', value: this.data.preference.motion === 'SIMPLE' ? '简洁' : '跟随系统', action: () => this.preference((pref: Preference) => pref.motion = pref.motion === 'SIMPLE' ? 'SYSTEM' : 'SIMPLE') })
    }
    GroupCard({ header: '提醒与卡片' }) {
      MenuRow({ plain: true, first: true, title: '到期提醒', value: this.data.preference.reminderEnabled ? '已开启' : '未开启', action: () => this.navigate('到期提醒') })
      this.toggleRow('外部提醒显示物品名称', '关闭时系统日历只显示数量', this.data.preference.externalDetails, false, (value: boolean) => this.preference((pref: Preference) => pref.externalDetails = value))
      this.toggleRow('在卡片展示物品摘要', '允许桌面显示名称、位置与日期', this.data.preference.cardSummary, false, (value: boolean) => this.preference((pref: Preference) => pref.cardSummary = value))
      MenuRow({ plain: true, title: '桌面随手可达', subtitle: '长按应用图标添加卡片，或直接记一件、找东西、看临期、扫一扫', action: ()=>this.navigate('快捷入口') })
    }
    if (this.data.preference.cardSummary) {
      Text('常用位置卡片：选择最多 3 条物品。日期关注卡片独立显示待处理日期，两种卡片可以同时添加。').fontColor($r('app.color.secondary'))
      ForEach(this.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED'), (item: Item) => {
        Row() {
          Checkbox({ name: item.id }).select(this.data.preference.cardIds.includes(item.id))
            .enabled(this.data.preference.cardIds.includes(item.id) || this.selectedCardIds().length < 3)
            .onChange((selected: boolean) => this.selectCardItem(item.id, selected))
          Text(displayName(item)).fontColor($r('app.color.text')).layoutWeight(1)
        }
      }, (item: Item) => item.id)
    }
    GroupCard({ header: '权限' }) {
      MenuRow({ plain: true, first: true, icon: $r('sys.symbol.calendar'), title: '日历访问', subtitle: '用于写入到期提醒', action: () => { abilityAccessCtrl.createAtManager().openPermissionOnSetting(this.getUIContext().getHostContext() as common.UIAbilityContext, 'ohos.permission.READ_CALENDAR').catch(() => this.notify('可在系统设置 → 应用 → 我的家当 → 权限中管理')); } })
      MenuRow({ plain: true, icon: $r('sys.symbol.mic'), title: '麦克风', subtitle: '用于语音填写和语音查找', action: () => { abilityAccessCtrl.createAtManager().openPermissionOnSetting(this.getUIContext().getHostContext() as common.UIAbilityContext, 'ohos.permission.MICROPHONE').catch(() => this.notify('可在系统设置 → 应用 → 我的家当 → 权限中管理')); } })
    }
    Text('字体与字号跟随系统设置。照片、名称和位置保存在这台设备的应用空间中；系统日历仅接收提醒日期与数量，开启“显示物品名称”后包含名称。系统备份按系统设置处理应用数据，导出文件保存在你选择的位置。').fontSize(13).fontColor($r('app.color.secondary'))
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
        if (this.panel === '拆分数量') { TextInput({ text: this.value, placeholder: '新记录名称' }).onChange((value: string) => this.value = value); Text(`原数量 ${this.current().quantity}，拆分后剩余 ${(this.current().quantity ?? 0) - Number(this.quantity)}`).fontColor($r('app.color.secondary')); Row() { Text('沿用日期').fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.keepDates }).selectedColor($r("app.color.primary")).onChange((value: boolean) => this.keepDates = value); } }
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
          else if (name === '应用图标') { this.iconPage() }
          else if (name === '帮助与关于') { this.help() }
          else if (name === '数据管理') { DataPage({repository:this.repository,onDone:()=>{this.stack.clear();this.tab=0;this.query='';this.scope='CURRENT';this.filter='全部';this.category='';this.refresh();}}) }
          else if (name === '到期提醒') { this.reminderSettings() }
          else if (name === '扫码查同款') { this.scanPage() }
          else if(name==='快捷入口'){SectionHeading({ title: '桌面卡片', subtitle: '长按桌面的我的家当图标 → 卡片，选择适合你的用途' });MenuRow({ title: '随手记 · 2×2', subtitle: '找东西与记一件，两个清楚的快捷入口', action: ()=>this.beginSearch() });MenuRow({ title: '常用位置 · 4×2', subtitle: '最多三条物品的位置，借出后显示借用人', action: ()=>this.navigate('外观与隐私') });MenuRow({ title: '日期关注 · 2×2 / 4×2', subtitle: '小卡关注一条，横向卡展示三条到期、归还或保修日期', action: ()=>this.navigate('提醒') });Text('常用位置和日期关注可以同时添加。开启桌面摘要后显示详情；关闭时隐藏所有物品信息，保留操作入口。').fontColor($r('app.color.secondary'));}
          else if (name === '照片') { PhotoViewer({ repository: this.repository, ids: this.previewPhotos, initialId: this.previewPhoto, onSelect: (id: string) => this.previewPhoto = id }); if (this.current().photoIds.includes(this.previewPhoto) && !this.current().deletedAt && this.current().status !== 'ARCHIVED') { ActionButton({ label: '设为主图', run: () => this.confirm('设为主图', '将当前照片放到这条记录的第一张', () => this.repository.mutate([this.focusedId], '调整主图', (item: Item) => item.photoIds = [this.previewPhoto, ...item.photoIds.filter((id: string) => id !== this.previewPhoto)])) }); ActionButton({ label: '编辑照片与提取文字', run: () => this.edit(this.current()) }); } }
          else if (name === '示例家当') { SectionHeading({ title: '示例家当', subtitle: '此处展示独立示例' }); MenuRow({ title: '旅行充电器', subtitle: '书房 / 书桌抽屉 · 在手 1 件', action: () => {} }); MenuRow({ title: '露营箱', subtitle: '储物间 / 上层 · 整组记录', action: () => {} }); MenuRow({ title: '备用钥匙', subtitle: '玄关 / 小抽屉 · 常用', action: () => {} }); ActionButton({ label: '开始记录自己的物品', run: () => { this.stack.pop(); this.newItem(); }, primary: true }); }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12, bottom: 32 })
      }.width('100%').height('100%').align(Alignment.TopStart)
    }.title(name).onShown(()=>{const index=this.stack.getAllPathName().lastIndexOf(name);const id=this.stack.getParamByIndex(index) as string;if(name==='位置详情' && id)this.focusedLocation=id;if(name==='物品详情' && id)this.focusedId=id;}).backgroundColor($r('app.color.background')).onBackPressed(() => { if (this.selecting) { this.endSelection(); return true; } if (name === '归档与回收站' || name === '搜索') { clearTimeout(this.queryTimer); this.scope = 'CURRENT'; this.query = ''; this.search(); } return false; })
  }
  @Builder editor() { ItemEditor({ repository: this.repository, initial: this.editorDraft, onView:(id:string)=>{this.editorOpen=false;this.refresh();this.detail(id);}, onFind:(name:string)=>{this.editorOpen=false;this.query=name;this.scope='CURRENT';this.filter='全部';this.category='';this.submitSearch();this.navigate('搜索');}, onReminder:()=>{this.editorOpen=false;this.navigate('到期提醒');}, onSaved: (id: string) => { this.focusedId = id; this.refresh(); if (this.editorDraft.mode === 'EDIT' && id === this.editorDraft.itemId) { this.editorOpen = false; this.notify('已保存'); } }, onClose: () => { this.editorOpen = false; this.refresh(); } }) }
  @Builder tabLabel(label:string,index:number){
    Column({ space: 2 }) {
      if (index === 0) { SymbolGlyph(this.tab===index?$r('sys.symbol.house_fill'):$r('sys.symbol.house')).fontSize(20).fontColor([this.tab===index?$r('app.color.primary'):$r('app.color.secondary')]) }
      else if (index === 1) { SymbolGlyph(this.tab===index?$r('sys.symbol.local_fill'):$r('sys.symbol.local')).fontSize(20).fontColor([this.tab===index?$r('app.color.primary'):$r('app.color.secondary')]) }
      else { SymbolGlyph(this.tab===index?$r('sys.symbol.person_fill'):$r('sys.symbol.person')).fontSize(20).fontColor([this.tab===index?$r('app.color.primary'):$r('app.color.secondary')]) }
      Text(label).fontSize(11).fontColor(this.tab===index?$r('app.color.primary'):$r('app.color.secondary')).fontWeight(this.tab===index?FontWeight.Medium:FontWeight.Regular)
    }.justifyContent(FlexAlign.Center).height(48).constraintSize({minWidth:64}).padding({left:10,right:10}).accessibilityGroup(true).accessibilityText(label).accessibilitySelected(this.tab===index)
  }
  @Builder captureButton(){Button({type:ButtonType.Circle}){SymbolGlyph($r('sys.symbol.plus')).fontSize(28).fontColor([$r('app.color.onPrimary')])}.width(56).height(56).backgroundColor($r('app.color.primary')).accessibilityText('记下一件').onClick(()=>this.newItem())}
  build() {
    Navigation(this.stack) {
      Column() {
        Blank().width(0).height(0).bindSheet($$this.editorOpen, this.editor, { height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: $r('app.color.background'), keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY, onDisappear: () => this.resumeEntry() })
        Blank().width(0).height(0).bindSheet($$this.panelOpen, this.actionPanel, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: true, backgroundColor: $r('app.color.background'), keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL, onDisappear: () => this.resumeEntry() })
        Blank().width(0).height(0).bindSheet($$this.shareOpen, this.share, { height: SheetSize.LARGE, showClose: false, onDisappear: () => this.resumeEntry() })
        if (!this.ready) {
          Column({ space: 12 }) {
            this.characterImage(128)
            Text(this.failure || '正在打开自己的家当').fontColor($r('app.color.text'))
            if (this.failure) { ActionButton({ label: '重新读取', run: () => this.open() }) }
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        }
        else {
          HdsTabs({index:this.tab,controller:this.tabsController}) {
            TabContent(){Scroll(this.homeScroller){Column({space:12}){this.home()}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(0,this.homeScroller))}.tabBar(this.tabLabel('家当',0))
            TabContent(){Scroll(this.locationScroller){Column({space:12}){this.locations(true)}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(1,this.locationScroller))}.tabBar(this.tabLabel('位置',1))
            TabContent(){Scroll(this.mineScroller){Column({space:12}){this.mine()}.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,bottom:110})}.width('100%').height('100%').align(Alignment.TopStart).onAppear(()=>this.tabsController.bindScroller(2,this.mineScroller))}.tabBar(this.tabLabel('我的',2))
          }.barPosition(BarPosition.End).vertical(false).barOverlap(true).scrollable(false).animationDuration(0)
          .barFloatingStyle({barWidth:{smallWidth:236,mediumWidth:300,largeWidth:360},barSideMargin:20,barBottomMargin:12,systemMaterialEffect:{materialType:hdsMaterial.MaterialType.IMMERSIVE,materialLevel:hdsMaterial.MaterialLevel.ADAPTIVE},miniBar:{miniBarBuilder:()=>{this.captureButton()},miniBarWidth:{smallWidth:56,mediumWidth:56,largeWidth:56}}})
          .onChange((index:number)=>{this.endSelection();this.tab=index;this.preference((pref:Preference)=>pref.lastTab=index);}).width('100%').layoutWeight(1).onAreaChange((oldArea:Area,newArea:Area)=>this.contentWidth=Number(newArea.width))
        }
      }.width('100%').height('100%').backgroundColor($r('app.color.background'))
    }.hideTitleBar(true).mode(NavigationMode.Auto).navBarWidth(360).navBarWidthRange([320, 480]).minContentWidth(360).navDestination(this.destination).backgroundColor($r('app.color.background'))
  }
}
