import { focusVisibleInput, ActionButton, MenuRow, GroupCard, Segmented } from './Common';
import { common } from '@kit.AbilityKit';
import { Item, Draft, ItemDate, copy, uuid, editorContent, expiryDate, setDate, displayName, validDate, normalize, shortDate, relativeDue, daysUntil, reminderClock, CATEGORY_CODES, CATEGORY_NAMES } from '../model/Models';
import { Repository } from '../data/Repository';
import { MediaService } from '../services/MediaService';
import { VoicePanel } from './VoicePanel';
import { LocationPicker } from './LocationPicker';
import { PhotoViewer } from './PhotoViewer';

@Component
export struct ItemEditor {
  repository: Repository = new Repository();
  initial: Draft = new Draft();
  onSaved: (id: string) => void = () => {};
  onView: (id: string) => void = () => {};
  onFind: (name: string) => void = () => {};
  onReminder: () => void = () => {};
  registerBack: (handler?: () => boolean) => void = () => {};
  @StorageProp('reducedMotion') reducedMotion: boolean = false;
  onClose: () => void = () => {};
  @State draft: Draft = new Draft();
  @State item: Item = new Item();
  @State more: boolean = false;
  @State datesOpen: boolean = false;
  @State busy: boolean = false;
  @State recognizing: boolean = false;
  @State error: string = '';
  @State receipt: string = '';
  @State choosingLocation: boolean = false;
  @State candidates: string = '';
  @State selectedText: string = '';
  @State previewId: string = '';
  private stopVoice?: () => void;
  @State voiceTarget: string = '';
  @State voiceOpen: boolean = false;
  @State conflict?: Item = undefined;
  @State missingOriginal: boolean = false;
  @State continuous: boolean = false;
  @State sessionSaved: number = 0;
  @State banner: string = '';
  private baselineLocation: string = '';
  private editBaseline?: string;
  private recognitionId: string = '';
  private recognitionTimer: number = -1;
  @StorageProp('backgroundAt') @Watch('saveOnBackground') backgroundAt: number = 0;
  private timer: number = -1;
  private alive: boolean = false;
  private operation: string = uuid();

  aboutToAppear(): void {
    this.registerBack(() => this.backToForm());
    this.alive = true; this.draft = copy(this.initial); this.item = copy(this.draft.payload);
    this.candidates = this.draft.candidates; this.more = false; this.baselineLocation = this.item.locationId;
    if (this.draft.mode === 'EDIT') {
      const original = this.repository.data.items.find((item: Item) => item.id === this.draft.itemId);
      if (original && !original.deletedAt && original.revision === this.draft.baseRevision) {
        this.editBaseline = editorContent(original);
      }
    }
  }
  private backToForm(): boolean {
    if (this.voiceOpen) this.voiceOpen = false;
    else if (this.previewId) this.previewId = '';
    else if (this.choosingLocation) this.choosingLocation = false;
    else return false;
    return true;
  }
  private changeSection(update: () => void): void {
    this.getUIContext().animateTo({ duration: this.reducedMotion ? 0 : 180, curve: Curve.EaseOut }, update);
  }
  private notify(message: string): void { try { this.getUIContext().getPromptAction().showToast({ message, duration: 2500 }); } catch (_) {} }
  private close(): void { this.persist(); if (this.sessionSaved > 1) this.notify(`这次记下了 ${this.sessionSaved} 条`); this.onClose(); }
  aboutToDisappear(): void { this.registerBack(undefined); this.persist(); this.alive = false; clearTimeout(this.timer); clearTimeout(this.recognitionTimer); this.recognitionId=''; }
  saveOnBackground(): void { this.persist(); }
  private media(): MediaService { return new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository); }
  private changed(): void { this.item = copy(this.item); this.error = ''; clearTimeout(this.timer); this.timer = setTimeout(() => this.persist(), 500); }
  private persist(): void {
    if (this.receipt || !this.alive) return;
    // 记录类型和带入的位置只是上下文，用户没有填写内容时不生成草稿
    const hasInput = !!(this.item.title.trim() || this.item.photoIds.length || this.item.notes.trim() || this.item.locationId !== this.baselineLocation || this.item.expiryInput.directDate || this.item.expiryInput.producedOn || this.item.expiryInput.value || this.item.aliases.length || this.item.tags.length || this.item.category || this.item.barcodeValue || this.item.dates.length || (this.item.kind === 'SINGLE' && this.item.quantity !== 1));
    const unchangedEdit = this.draft.mode === 'EDIT' && !this.candidates && this.editBaseline === editorContent(this.item);
    const stored = this.repository.data.drafts.find((draft: Draft) => draft.id === this.draft.id);
    try {
      if ((this.draft.mode === 'CREATE' && !hasInput) || unchangedEdit) {
        if (stored) this.repository.deleteDraft(this.draft.id);
        return;
      }
      if (stored && stored.baseRevision === this.draft.baseRevision && stored.candidates === this.candidates &&
        JSON.stringify(stored.payload) === JSON.stringify(this.item)) return;
      this.draft.payload = copy(this.item); this.draft.candidates = this.candidates;
      this.repository.saveDraft(this.draft);
    } catch (error) { this.error = `草稿暂未保存：${(error as Error).message}`; }
  }
  private async photos(camera: boolean): Promise<void> {
    if (this.busy) return; this.busy = true; this.error = ''; const session = this.draft.id;
    try {
      const media = this.media(); const uris = camera ? await media.camera() : await media.pick(6 - this.item.photoIds.length);
      for (const uri of uris) {
        const asset = await media.importImage(uri);
        if (!this.alive || this.draft.id !== session) return;
        if (!this.item.photoIds.includes(asset.id)) this.item.photoIds.push(asset.id); this.changed(); this.persist();
      }
    } catch (error) { this.error = `图片未加入：${(error as Error).message}`; }
    finally { this.busy = false; }
  }
  private async recognize(): Promise<void> {
    if (this.recognizing || !this.item.photoIds.length) return;
    this.recognizing = true; const session = this.draft.id; const request=uuid();this.recognitionId=request;
    this.recognitionTimer=setTimeout(()=>{if(this.alive && this.recognitionId===request)this.error='文字提取耗时较长，可以继续编辑或先保存照片';},8000);
    try { const text = await this.media().recognize(this.previewId || this.item.photoIds[0]); if (this.alive && session === this.draft.id && !this.receipt && this.recognitionId===request) { this.candidates = text; this.error = text.trim() ? '' : '未提取到可用文字，可以继续输入或换张照片'; this.persist(); } }
    catch (error) { if(this.alive && this.recognitionId===request)this.error = (error as Error).message; } finally { clearTimeout(this.recognitionTimer);this.recognizing = false; }
  }
  private candidateDates():string[]{const values=this.candidates.match(/(?:19\d{2}|20\d{2}|21\d{2}|2200)[年./-]\d{1,2}[月./-]\d{1,2}日?/g)??[];return Array.from(new Set(values.map((value:string)=>{const parts=value.match(/\d+/g)??[];return parts[0]+'-'+parts[1].padStart(2,'0')+'-'+parts[2].padStart(2,'0');}).filter((value:string)=>validDate(value)))).slice(0,8);}
  private candidateNames(): string[] {
    const seen: string[] = [];
    return [this.selectedText, ...this.candidates.split('\n')].map((value: string) => value.trim()).filter((value: string) => { const key = normalize(value); if (!key || Array.from(value).length > 80 || seen.includes(key)) return false; seen.push(key); return true; }).slice(0, 3);
  }
  private appendNotes(value: string): void {
    const combined = [this.item.notes, value].filter((text: string) => !!text).join('\n');
    if (Array.from(combined).length > 2000) { this.error = '补充后超过 2000 字，请选取较短的文字片段'; return; }
    this.item.notes = combined; this.changed();
  }
  private saveAsNew():void {this.item.id=uuid();this.item.revision=0;this.item.deletedAt=0;this.item.purgeAt=0;this.item.status='ACTIVE';this.item.borrower='';this.item.lentAt=0;this.item.archiveReason='';this.item.archivedAt=0;this.item.createdAt=Date.now();this.item.dates.forEach((date:ItemDate)=>{date.id=uuid();date.itemId=this.item.id;date.dateVersion=1;date.handledAt=0;});this.draft.mode='CREATE';this.draft.itemId='';this.conflict=undefined;this.missingOriginal=false;this.operation=uuid();this.changed();}
  private resultDate(): string { try { return expiryDate(this.item.expiryInput); } catch (error) { return ''; } }
  private expiryProblem(): string {
    const input = this.item.expiryInput;
    if (input.mode === 'SHELF_LIFE' && !input.value) return '';
    try { expiryDate(input); return ''; } catch (error) { return (error as Error).message; }
  }
  private reminderNote(date: string): string {
    if (!date) return '';
    const days = daysUntil(date);
    if (days < 0) return relativeDue(date) + '，不会再提醒，可在“提醒”里处理';
    if (!this.repository.data.preference.reminderEnabled) return relativeDue(date) + ' · 开启提醒后当天 ' + reminderClock() + ' 通知';
    if (days === 0 && new Date().getHours() >= 9) return '今天到期，今天的提醒时间已过';
    return relativeDue(date) + ' · 当天 ' + reminderClock() + ' 提醒';
  }
  private movePhoto(id: string, offset: number): void {
    const from = this.item.photoIds.indexOf(id); const to = from + offset;
    if (from < 0 || to < 0 || to >= this.item.photoIds.length) return;
    const ids = [...this.item.photoIds]; ids.splice(from, 1); ids.splice(to, 0, id); this.item.photoIds = ids; this.changed();
  }
  private dateValue(type: string): string { return this.item.dates.find((date: ItemDate) => date.type === type)?.date ?? ''; }
  private pickDate(type: string): void {
    const value = type === 'direct' ? this.item.expiryInput.directDate : type === 'produced' ? this.item.expiryInput.producedOn : this.dateValue(type);
    this.getUIContext().showDatePickerDialog({ start: new Date(1900, 0, 1), end: new Date(2200, 11, 31), selected: value ? new Date(value + 'T12:00:00') : new Date(), onDateAccept: (date: Date) => {
      const text = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
      if (type === 'direct') this.item.expiryInput.directDate = text;
      else if (type === 'produced') this.item.expiryInput.producedOn = text;
      else setDate(this.item, type, text); this.changed();
    } });
  }
  private save(): void {
    if (this.busy || this.receipt) return; this.busy = true;
    try {
      const id = this.repository.saveItem(this.item, this.draft.id, this.operation);
      if (this.draft.mode === 'EDIT') this.receipt = id;
      if (this.draft.mode === 'CREATE') this.sessionSaved++;
      this.onSaved(id);
      if (this.continuous && this.draft.mode === 'CREATE') {
        const date = this.resultDate();
        this.banner = `已记下「${displayName(this.item)}」` + (date && daysUntil(date) < 0 ? ' · ' + relativeDue(date) : '') + ` · 这次第 ${this.sessionSaved} 条`;
        this.next(); this.continuous = true;
      } else this.changeSection(() => this.receipt = id);
    }
    catch (error) { this.error = (error as Error).message; if(this.draft.mode==='EDIT'){const current=this.repository.data.items.find((item:Item)=>item.id===this.item.id);this.conflict=current?copy(current):undefined;this.missingOriginal=!current;} this.persist(); }
    finally { this.busy = false; }
  }
  private placeSaved(id: string): void {
    this.choosingLocation = false;
    if (!id) return;
    try {
      this.repository.mutate([this.receipt], '改位置', (item: Item) => item.locationId = id);
      this.item.locationId = id; this.item = copy(this.item); this.onSaved(this.receipt);
    } catch (error) { this.error = (error as Error).message; }
  }
  private next(): void {
    const draft = new Draft(); draft.payload.locationId = this.item.locationId; draft.payload.kind = this.item.kind; draft.sessionId = this.draft.sessionId;
    this.draft = draft; this.item = copy(draft.payload); this.receipt = ''; this.candidates = ''; this.operation = uuid(); this.more = false; this.datesOpen = false;
    this.baselineLocation = this.item.locationId; this.continuous = true; this.error = '';
    focusVisibleInput(this.getUIContext(), 'nameInput');
  }
  @Builder photoTile(icon: Resource, label: string, run: () => void) {
    Column({ space: 6 }) {
      SymbolGlyph(icon).fontSize(26).fontColor([$r('app.color.primary')])
      Text(label).fontSize(13).fontColor($r('app.color.primary'))
    }.stateStyles({ pressed: { .opacity(0.75) } }).width(84).height(84).justifyContent(FlexAlign.Center).backgroundColor($r('app.color.subtle')).borderRadius(16)
    .accessibilityGroup(true).accessibilityText(label).onClick(() => run())
  }
  private moreSummary(): string {
    const parts: string[] = [];
    if (this.item.category) parts.push(CATEGORY_NAMES[CATEGORY_CODES.indexOf(this.item.category)]);
    if (this.item.kind === 'SINGLE' && (this.item.quantity ?? 1) !== 1) parts.push(`${this.item.quantity} 件`);
    if (this.item.aliases.length) parts.push('也叫 ' + this.item.aliases.join('、'));
    if (this.item.tags.length) parts.push(this.item.tags.map((tag: string) => '#' + tag).join(' '));
    if (this.item.kind === 'SINGLE' && this.item.notes) parts.push('有说明');
    return parts.join(' · ') || (this.item.kind === 'GROUP' ? '分类、别名、标签' : '数量、说明、分类、别名');
  }
  @Builder label(text: string) { Text(text).fontSize(14).fontColor($r('app.color.secondary')).width('100%') }
  @Builder dates() {
    this.label('到期日期 · 选填')
    Segmented({ options: ['直接填日期', '按保质期计算'], selected: this.item.expiryInput.mode === 'SHELF_LIFE' ? 1 : 0, onSelect: (index: number) => { this.item.expiryInput.mode = index ? 'SHELF_LIFE' : 'DIRECT'; this.changed(); } })
    if (this.item.expiryInput.mode === 'DIRECT') {
      ActionButton({ label: this.item.expiryInput.directDate ? '到期：' + shortDate(this.item.expiryInput.directDate) : '选择到期日期', icon: $r('sys.symbol.calendar'), tonal: true, run: () => this.pickDate('direct') })
    } else {
      ActionButton({ label: this.item.expiryInput.producedOn ? '生产：' + shortDate(this.item.expiryInput.producedOn) : '选择生产日期', icon: $r('sys.symbol.calendar'), tonal: true, run: () => this.pickDate('produced') })
      Row({ space: 8 }) {
        TextInput({ placeholder: '保质期', text: this.item.expiryInput.value ? String(this.item.expiryInput.value) : '' }).type(InputType.Number).layoutWeight(1).onChange((value: string) => { this.item.expiryInput.value = Number(value); this.changed(); })
        Select([{ value: '天' }, { value: '月' }, { value: '年' }]).value(this.item.expiryInput.unit === 'DAY' ? '天' : this.item.expiryInput.unit === 'YEAR' ? '年' : '月').onSelect((index: number) => { this.item.expiryInput.unit = ['DAY', 'MONTH', 'YEAR'][index]; this.changed(); })
      }
    }
    if (this.item.expiryInput.mode === 'SHELF_LIFE') {
      if (this.expiryProblem()) { Text(this.expiryProblem()).fontSize(14).fontColor($r('app.color.danger')) }
      else { Text(this.resultDate() ? '算出的到期日期：' + shortDate(this.resultDate()) : '填写生产日期和保质期，自动算出到期日期').fontSize(14).fontColor(this.resultDate() ? $r('app.color.primary') : $r('app.color.secondary')) }
    }
    if (this.resultDate()) { Text(this.reminderNote(this.resultDate())).fontSize(13).fontColor(daysUntil(this.resultDate()) < 0 ? $r('app.color.warning') : $r('app.color.secondary')) }
    else { Text('到期当天 ' + reminderClock() + ' 提醒一次，同一天的合成一条').fontSize(13).fontColor($r('app.color.secondary')) }
    if (this.item.expiryInput.directDate || this.item.expiryInput.producedOn || this.item.expiryInput.value) { ActionButton({ label: '移除到期日期', run: () => { this.item.expiryInput.mode = 'DIRECT'; this.item.expiryInput.directDate = ''; this.item.expiryInput.producedOn = ''; this.item.expiryInput.value = 0; this.changed(); } }) }
    Row({ space: 8 }) {
      ActionButton({ label: this.dateValue('WARRANTY') ? '保修至 ' + shortDate(this.dateValue('WARRANTY')) : '保修日期', icon: $r('sys.symbol.checkmark_shield'), tonal: true, run: () => this.pickDate('WARRANTY') })
      if (this.dateValue('WARRANTY')) { ActionButton({ label: '清除保修', run: () => { setDate(this.item, 'WARRANTY', ''); this.changed(); } }) }
    }
    if (this.item.status === 'LENT') {
      ActionButton({ label: this.dateValue('RETURN') ? '归还 ' + shortDate(this.dateValue('RETURN')) : '归还日期', run: () => this.pickDate('RETURN') })
    }
  }
  @Builder form() {
    if (this.banner) { Text(this.banner).fontSize(14).fontColor($r('app.color.primary')).width('100%').padding(12).backgroundColor($r('app.color.subtle')).borderRadius(14) }
    Row() {
      TextInput({ text: this.item.title, placeholder: this.item.kind === 'GROUP' ? '给这一组起个名字，例如：露营箱' : '给它起个容易想起的名字' }).id('nameInput').fontSize(22).height(60).backgroundColor(Color.Transparent).maxLength(80).enterKeyType(EnterKeyType.Done).layoutWeight(1)
        .onChange((value: string) => { this.item.title = value; this.changed(); })
        .onSubmit(() => { if (this.item.title.trim() || this.item.photoIds.length) this.save(); })
        .onAppear(() => { if (this.continuous) focusVisibleInput(this.getUIContext(), 'nameInput'); })
      Stack() { SymbolGlyph($r('sys.symbol.mic')).fontSize(22).fontColor([$r('app.color.primary')]) }
        .width(48).height(48).borderRadius(24).accessibilityText('语音填写名称').accessibilityLevel('yes')
        .onClick(() => { if (!this.voiceOpen) { this.voiceTarget = '名称'; this.voiceOpen = true; } })
    }.width('100%').padding({ right: 6 }).backgroundColor($r('app.color.surface')).borderRadius(16)
    Segmented({ options: ['记一件', '记一组'], selected: this.item.kind === 'GROUP' ? 1 : 0, onSelect: (index: number) => { if (index) { this.item.kind = 'GROUP'; } else { this.item.kind = 'SINGLE'; this.item.quantity = Math.max(1, this.item.quantity ?? 1); } this.changed(); } })
    if (this.item.kind === 'GROUP') {
      this.label('这组里面有什么 · 搜索时会用到')
      Stack({ alignContent: Alignment.BottomEnd }) {
        TextArea({ text: this.item.notes, placeholder: '例如：炉头、气罐、折叠碗、头灯' }).maxLength(2000).constraintSize({ minHeight: 96 }).backgroundColor($r('app.color.surface')).borderRadius(16).padding({ right: 48 }).onChange((value: string) => { this.item.notes = value; this.changed(); })
        Stack() { SymbolGlyph($r('sys.symbol.mic')).fontSize(20).fontColor([$r('app.color.primary')]) }
          .width(44).height(44).borderRadius(22).margin(4).accessibilityText('语音填写组里的东西').accessibilityLevel('yes')
          .onClick(() => { if (!this.voiceOpen) { this.voiceTarget = '说明'; this.voiceOpen = true; } })
      }.width('100%')
    }
    Scroll() {
      Row({ space: 10 }) {
        if (this.item.photoIds.length < 6) {
          this.photoTile($r('sys.symbol.camera'), '拍照', () => this.photos(true))
          this.photoTile($r('sys.symbol.picture'), '相册', () => this.photos(false))
        }
        ForEach(this.item.photoIds, (id: string, index: number) => {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(this.media().uri(id, true)).width(84).height(84).objectFit(ImageFit.Cover).borderRadius(16).accessibilityText(`${index === 0 ? '主图' : '照片'}，第 ${index + 1} 张`).onClick(() => { this.previewId = id; })
            Stack() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(12).fontColor([Color.White]) }
              .width(24).height(24).borderRadius(12).backgroundColor('#99000000').margin(4)
              .accessibilityText(`移除第 ${index + 1} 张照片`).accessibilityLevel('yes')
              .onClick(() => { this.item.photoIds = this.item.photoIds.filter((value: string) => value !== id); this.changed(); })
            if (index === 0 && this.item.photoIds.length > 1) { Text('主图').fontSize(11).fontColor(Color.White).padding({ left: 6, right: 6, top: 2, bottom: 2 }).backgroundColor('#99000000').borderRadius(8).position({ left: 6, bottom: 6 }) }
          }.width(84).height(84)
        }, (id: string, index: number) => id + ':' + index)
        if (this.busy) { Stack() { LoadingProgress().width(28).height(28) }.width(84).height(84).borderRadius(16).backgroundColor($r('app.color.subtle')) }
      }
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').align(Alignment.Start).enabled(!this.busy)
    GroupCard() {
      MenuRow({ plain: true, first: true, icon: $r('sys.symbol.mappin_and_rectangle'), title: '放在哪里', subtitle: this.repository.path(this.item.locationId) || '稍后也能补充', action: () => this.choosingLocation = true })
      MenuRow({ plain: true, icon: $r('sys.symbol.calendar'), title: '日期', subtitle: [this.resultDate() ? relativeDue(this.resultDate()) + '（' + shortDate(this.resultDate()) + '）' : '', this.dateValue('WARRANTY') ? '保修至 ' + shortDate(this.dateValue('WARRANTY')) : '', this.item.status === 'LENT' && this.dateValue('RETURN') ? '归还 ' + shortDate(this.dateValue('RETURN')) : ''].filter((value: string) => !!value).join(' · ') || '到期、保修，按需记下', value: this.datesOpen ? '收起' : '', chevron: !this.datesOpen, action: () => this.changeSection(() => this.datesOpen = !this.datesOpen) })
      if (this.datesOpen) { Column({ space: 12 }) { this.dates() }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 16 }) }
      MenuRow({ plain: true, icon: $r('sys.symbol.list_bullet'), title: '更多信息', subtitle: this.moreSummary(), value: this.more ? '收起' : '', chevron: !this.more, action: () => this.changeSection(() => this.more = !this.more) })
    }
    if (this.more) {
      this.label('分类')
      Select(CATEGORY_NAMES.map((name: string): SelectOption => ({ value: name }))).value(CATEGORY_NAMES[CATEGORY_CODES.indexOf(this.item.category)]).onSelect((index: number) => { this.item.category = CATEGORY_CODES[index]; this.changed(); })
      if (this.item.kind === 'SINGLE') {
        this.label('数量（1—9999）')
        TextInput({ text: String(this.item.quantity), placeholder: '数量' }).type(InputType.Number).onChange((value: string) => { this.item.quantity = Number(value); this.changed(); })
      }
      this.label('别名 · 用顿号分隔')
      TextInput({ text: this.item.aliases.join('、'), placeholder: '你还会怎样叫它' }).onChange((value: string) => { this.item.aliases = value.split(/[、,，]/).map((part: string) => part.trim()).filter((part: string) => !!part); this.changed(); })
      this.label('标签 · 用顿号分隔')
      TextInput({ text: this.item.tags.join('、'), placeholder: '旅行、备用' }).onChange((value: string) => { this.item.tags = value.split(/[、,，]/).map((part: string) => part.trim()).filter((part: string) => !!part); this.changed(); })
      if (this.item.kind === 'SINGLE') {
        this.label('说明')
        ActionButton({ label: '语音填写说明', icon: $r('sys.symbol.mic'), run: ()=>{if(!this.voiceOpen){this.voiceTarget='说明';this.voiceOpen=true;}} })
        TextArea({ text: this.item.notes, placeholder: '留一点线索，给下次寻找的自己。' }).maxLength(2000).constraintSize({ minHeight: 100 }).onChange((value: string) => { this.item.notes = value; this.changed(); })
      }
      if (this.item.barcodeValue) { Text('商品条码：' + this.item.barcodeValue).fontSize(14) }
    }
    if (this.item.photoIds.length) { ActionButton({ label: this.recognizing ? '正在提取，可继续编辑或保存' : '提取照片文字', icon: $r('sys.symbol.doc_plaintext'), tonal: true, run: () => this.recognize() }) }
    if (this.candidates) {
      this.label('照片文字 · 选择后才会填入')
      Text('当前名称：' + (this.item.title || '未填写')).fontColor($r('app.color.secondary'))
      TextArea({ text: this.candidates }).onChange((value: string) => { this.candidates = value; this.persist(); }).onTextSelectionChange((start: number, end: number) => this.selectedText = this.candidates.slice(start, end)).constraintSize({ minHeight: 100 })
      ForEach(this.candidateNames(), (line: string) => {
        ActionButton({ label: '用作名称：' + line, run: () => { this.item.title = line; this.changed(); } })
      })
      ActionButton({ label: this.selectedText ? '将选中文字补充到说明' : '将原文补充到说明', run: () => this.appendNotes(this.selectedText || this.candidates) })
      ForEach(this.candidateDates(),(value:string)=>{
        Text('识别到的日期：'+value).fontColor($r('app.color.text'))
        Row({space:8}){ActionButton({label:'作为到期日',run:()=>{this.item.expiryInput.mode='DIRECT';this.item.expiryInput.directDate=value;this.datesOpen=true;this.changed();}});ActionButton({label:'作为生产日',run:()=>{this.item.expiryInput.mode='SHELF_LIFE';this.item.expiryInput.producedOn=value;this.datesOpen=true;this.changed();}});}
        Row({ space: 8 }) { ActionButton({ label: '作为保修日', run: () => { setDate(this.item, 'WARRANTY', value); this.datesOpen = true; this.changed(); } }); if (this.item.status === 'LENT') { ActionButton({ label: '作为归还日', run: () => { setDate(this.item, 'RETURN', value); this.datesOpen = true; this.changed(); } }) } }
      })
    }
  }
  @Builder voice() { VoicePanel({target:this.voiceTarget,registerStop:(stop?:()=>void)=>this.stopVoice=stop,currentValue:this.voiceTarget==='名称'?this.item.title:this.item.notes,maxLength:this.voiceTarget==='名称'?80:2000,append:this.voiceTarget==='说明',onAdopt:(text:string)=>{if(this.voiceTarget==='名称')this.item.title=text;else this.item.notes=[this.item.notes,text].filter((value:string)=>!!value).join('\n');this.voiceOpen=false;this.changed();},onCancel:()=>this.voiceOpen=false}) }
  build() {
    Column() {
      Row() {
        Text(this.receipt ? '已记下' : this.draft.mode === 'EDIT' ? '编辑物品' : this.continuous ? '继续记下' : '记下').fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
        Button(this.continuous && !this.receipt ? '完成这次整理' : '关闭').fontColor(this.continuous && !this.receipt ? $r('app.color.primary') : $r('app.color.secondary')).backgroundColor(Color.Transparent).height(48).onClick(() => this.close())
      }.padding({ left: 20, right: 12, top: 12 }).width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (this.receipt && this.choosingLocation) {
            // 保存后补位置：直接更新刚保存的记录，不再经过草稿
            LocationPicker({ repository: this.repository, selected: '', title: '放在哪里', cancelLabel: '返回', onChoose: (id: string) => { this.placeSaved(id); }, onCancel: () => this.choosingLocation = false })
          } else if (this.receipt) {
            Column({ space: 8 }) {
              Row({ space: 10 }) { SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(28).fontColor([$r('app.color.primary')]); Text(displayName(this.item)).fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }.width('100%')
              Text(this.repository.path(this.item.locationId) ? '放在 ' + this.repository.path(this.item.locationId) : '已记下，随时可以补上位置').fontSize(16).fontColor($r('app.color.secondary'))
              if (this.resultDate()) { Text(this.reminderNote(this.resultDate())).fontSize(15).fontColor(daysUntil(this.resultDate()) < 0 ? $r('app.color.warning') : $r('app.color.primary')) }
              if (this.sessionSaved > 1) { Text(`这次记下了 ${this.sessionSaved} 条`).fontSize(15).fontColor($r('app.color.secondary')) }
            }.alignItems(HorizontalAlign.Start).width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20).margin({ top: 8 })
            if (!this.item.locationId && this.draft.mode !== 'EDIT') { ActionButton({ label: '现在补上位置', icon: $r('sys.symbol.mappin_and_rectangle'), tonal: true, run: () => this.choosingLocation = true }) }
            if (this.draft.mode !== 'EDIT') { ActionButton({ label: '继续记下', icon: $r('sys.symbol.plus'), primary: true, run: () => this.next() }) }
            Row({ space: 8 }) {
              ActionButton({ label: '查看这件', icon: $r('sys.symbol.eye'), tonal: true, run: () => this.onView(this.receipt) })
              if (this.item.title && this.repository.data.items.filter((value: Item) => !value.deletedAt).length === 1) { ActionButton({ label: '试着找一下', icon: $r('sys.symbol.magnifyingglass'), tonal: true, run: () => this.onFind(this.item.title) }) }
              if (this.resultDate() && !this.repository.data.preference.reminderEnabled) { ActionButton({ label: '开启到期提醒', icon: $r('sys.symbol.bell'), tonal: true, run: () => this.onReminder() }) }
            }
            ActionButton({ label: this.sessionSaved > 1 ? '完成这次整理' : '完成', run: () => this.close() })
          } else if (this.previewId) {
            PhotoViewer({ repository: this.repository, ids: this.item.photoIds, initialId: this.previewId, onSelect: (id: string) => this.previewId = id })
            ActionButton({ label: '设为主图', run: () => { this.item.photoIds = [this.previewId, ...this.item.photoIds.filter((id: string) => id !== this.previewId)]; this.changed(); this.previewId = ''; } })
            Text(`第 ${this.item.photoIds.indexOf(this.previewId) + 1} / ${this.item.photoIds.length} 张`).fontColor($r('app.color.secondary'))
            Row({ space: 8 }) { ActionButton({ label: '向前移', run: () => this.movePhoto(this.previewId, -1) }); ActionButton({ label: '向后移', run: () => this.movePhoto(this.previewId, 1) }); }
            ActionButton({ label: '提取文字', run: () => this.recognize() })
            ActionButton({ label: '返回编辑', run: () => this.previewId = '' })
          } else if (this.choosingLocation) { LocationPicker({ repository: this.repository, selected: this.item.locationId, onChoose: (id: string) => { this.item.locationId = id; this.choosingLocation = false; this.changed(); }, onCancel: () => this.choosingLocation = false }) }
          else { this.form() }
          if (this.error) { Text(this.error).fontColor($r('app.color.danger')).fontSize(15).width('100%') }
          if(this.conflict || this.missingOriginal){
            Text('这份草稿：'+displayName(this.item)+' · '+this.item.notes).fontColor($r('app.color.text'))
            if(this.conflict){
              Text('当前记录：'+displayName(this.conflict)+' · '+this.conflict.notes+' · '+this.repository.path(this.conflict.locationId)).fontColor($r('app.color.secondary'))
              ActionButton({label:'采用当前记录继续编辑',run:()=>{if(this.conflict){this.item=copy(this.conflict);this.draft.baseRevision=this.item.revision;this.editBaseline=editorContent(this.item);this.conflict=undefined;this.changed();}}})
              if(!this.conflict.deletedAt){ActionButton({label:'确认用这份草稿保存',run:()=>{if(this.conflict){this.item.revision=this.conflict.revision;this.conflict=undefined;this.save();}}});}
            }
            ActionButton({label:'保留原记录，另存为新记录',run:()=>this.saveAsNew()})
          }
        }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      }.nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .layoutWeight(1).width('100%').align(Alignment.TopStart)
      if (!this.receipt && !this.choosingLocation && !this.previewId) {
        Column({ space: 6 }) {
          if (!this.item.title.trim() && !this.item.photoIds.length) { Text('写个名称，或加张照片').fontSize(13).fontColor($r('app.color.secondary')) }
          Button(this.busy ? '正在处理' : this.draft.mode === 'EDIT' ? '保存修改' : '保存').height(50).width('100%').backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).enabled(!this.busy && (!!this.item.title.trim() || !!this.item.photoIds.length)).onClick(() => this.save())
        }.padding({ left: 20, right: 20, top: 8, bottom: 16 }).backgroundColor($r('app.color.surface'))
      }
    }.height('100%').width('100%').backgroundColor($r('app.color.background'))
      .bindSheet($$this.voiceOpen, this.voice, { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false,
        backgroundColor: $r('app.color.background'), onWillDisappear: () => this.stopVoice?.() })
  }
}
