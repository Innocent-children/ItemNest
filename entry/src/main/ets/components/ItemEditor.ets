import { ActionButton, MenuRow } from './Common';
import { common } from '@kit.AbilityKit';
import { Item, Draft, ItemDate, copy, uuid, expiryDate, setDate, displayName, validDate, normalize, CATEGORY_CODES, CATEGORY_NAMES } from '../model/Models';
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
  @State zoom: number = 1;
  @State voiceTarget: string = '';
  @State voiceOpen: boolean = false;
  @State conflict?: Item = undefined;
  @State missingOriginal: boolean = false;
  private recognitionId: string = '';
  private recognitionTimer: number = -1;
  @StorageProp('backgroundAt') @Watch('saveOnBackground') backgroundAt: number = 0;
  private timer: number = -1;
  private alive: boolean = false;
  private operation: string = uuid();

  aboutToAppear(): void { this.alive = true; this.draft = copy(this.initial); this.item = copy(this.draft.payload); this.candidates = this.draft.candidates; this.more = false; }
  aboutToDisappear(): void { this.persist(); this.alive = false; clearTimeout(this.timer); clearTimeout(this.recognitionTimer); this.recognitionId=''; }
  saveOnBackground(): void { this.persist(); }
  private media(): MediaService { return new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository); }
  private changed(): void { this.item = copy(this.item); this.error = ''; clearTimeout(this.timer); this.timer = setTimeout(() => this.persist(), 500); }
  private persist(): void {
    if (this.receipt || !this.alive) return;
    const hasInput = !!(this.item.title.trim() || this.item.photoIds.length || this.item.notes || this.item.locationId || this.item.expiryInput.directDate || this.item.expiryInput.producedOn || this.item.expiryInput.value || this.item.aliases.length || this.item.tags.length || this.item.category || this.item.barcodeValue || this.item.dates.length || this.item.kind === 'GROUP' || this.item.quantity !== 1);
    if (this.draft.mode === 'CREATE' && !hasInput) { if (this.repository.data.drafts.some((draft: Draft) => draft.id === this.draft.id)) this.repository.deleteDraft(this.draft.id); return; }
    this.draft.payload = copy(this.item); this.draft.candidates = this.candidates;
    try { this.repository.saveDraft(this.draft); } catch (error) { this.error = `草稿暂未保存：${(error as Error).message}`; }
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
  private resultDate(): string { try { return expiryDate(this.item.expiryInput); } catch (error) { return (error as Error).message; } }
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
    try { const id = this.repository.saveItem(this.item, this.draft.id, this.operation); this.receipt = id; this.onSaved(id); }
    catch (error) { this.error = (error as Error).message; if(this.draft.mode==='EDIT'){const current=this.repository.data.items.find((item:Item)=>item.id===this.item.id);this.conflict=current?copy(current):undefined;this.missingOriginal=!current;} this.persist(); }
    finally { this.busy = false; }
  }
  private next(): void {
    const draft = new Draft(); draft.payload.locationId = this.item.locationId; draft.payload.kind = this.item.kind; draft.sessionId = this.draft.sessionId;
    this.draft = draft; this.item = copy(draft.payload); this.receipt = ''; this.candidates = ''; this.operation = uuid(); this.more = false; this.datesOpen = false;
  }
  @Builder label(text: string) { Text(text).fontSize(14).fontColor($r('app.color.secondary')).width('100%') }
  @Builder dates() {
    this.label('到期日期 · 选填')
    Row({ space: 8 }) {
      ActionButton({ label: '直接填日期', run: () => { this.item.expiryInput.mode = 'DIRECT'; this.changed(); } })
      ActionButton({ label: '按保质期计算', run: () => { this.item.expiryInput.mode = 'SHELF_LIFE'; this.changed(); } })
    }
    if (this.item.expiryInput.mode === 'DIRECT') {
      ActionButton({ label: this.item.expiryInput.directDate || '选择到期日期', run: () => this.pickDate('direct') })
    } else {
      ActionButton({ label: this.item.expiryInput.producedOn || '选择生产日期', run: () => this.pickDate('produced') })
      Row({ space: 8 }) {
        TextInput({ placeholder: '保质期', text: this.item.expiryInput.value ? String(this.item.expiryInput.value) : '' }).type(InputType.Number).layoutWeight(1).onChange((value: string) => { this.item.expiryInput.value = Number(value); this.changed(); })
        Select([{ value: '天' }, { value: '月' }, { value: '年' }]).value(this.item.expiryInput.unit === 'DAY' ? '天' : this.item.expiryInput.unit === 'YEAR' ? '年' : '月').onSelect((index: number) => { this.item.expiryInput.unit = ['DAY', 'MONTH', 'YEAR'][index]; this.changed(); })
      }
    }
    if (this.item.expiryInput.mode === 'SHELF_LIFE') { Text(this.resultDate() ? '到期日期：' + this.resultDate() : '补上日期后可安排到期当天提醒').fontSize(14).fontColor($r('app.color.primary')) }
    Text(this.repository.data.preference.reminderEnabled ? '到期当天上午 9:00 提醒，同一天合成一条' : '开启提醒后，到期当天上午 9:00 提醒').fontSize(13).fontColor($r('app.color.secondary'))
    if (this.item.expiryInput.directDate || this.item.expiryInput.producedOn || this.item.expiryInput.value) { ActionButton({ label: '移除到期日期', run: () => { this.item.expiryInput.mode = 'DIRECT'; this.item.expiryInput.directDate = ''; this.item.expiryInput.producedOn = ''; this.item.expiryInput.value = 0; this.changed(); } }) }
    Row({ space: 8 }) {
      ActionButton({ label: this.dateValue('WARRANTY') || '保修日期', run: () => this.pickDate('WARRANTY') })
      if (this.dateValue('WARRANTY')) { ActionButton({ label: '清除保修', run: () => { setDate(this.item, 'WARRANTY', ''); this.changed(); } }) }
    }
    if (this.item.status === 'LENT') {
      ActionButton({ label: this.dateValue('RETURN') || '归还日期', run: () => this.pickDate('RETURN') })
    }
  }
  @Builder form() {
    TextInput({ text: this.item.title, placeholder: '给它起个容易想起的名字' }).fontSize(22).height(64).backgroundColor(Color.Transparent).maxLength(80).onChange((value: string) => { this.item.title = value; this.changed(); })
    Row({ space: 10 }) {
      ActionButton({ label: this.item.kind === 'SINGLE' ? '✓ 记一件' : '记一件', run: () => { if (this.item.kind === 'GROUP') this.more = true; this.item.kind = 'SINGLE'; this.item.quantity = Math.max(1, this.item.quantity ?? 1); this.changed(); } })
      ActionButton({ label: this.item.kind === 'GROUP' ? '✓ 记一组' : '记一组', run: () => { this.item.kind = 'GROUP'; this.changed(); } })
    }
    if (this.item.kind === 'GROUP') { Text('以一组呈现，组内物品记在照片和说明里').fontSize(14).fontColor($r('app.color.secondary')) }
    if (this.item.photoIds.length) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.item.photoIds, (id: string, index: number) => {
            Column({ space: 6 }) {
              Image(this.media().uri(id, true)).width(100).height(100).objectFit(ImageFit.Cover).borderRadius(16).accessibilityText(`${index === 0 ? '主图' : '照片'}，第 ${index + 1} 张`).onClick(() => { this.previewId = id; this.zoom = 1; })
              Button(index === 0 ? '主图 · 移除' : '移除').fontSize(12).height(36).onClick(() => { this.item.photoIds = this.item.photoIds.filter((value: string) => value !== id); this.changed(); })
            }
          }, (id: string, index: number) => id + ':' + index)
        }
      }.scrollable(ScrollDirection.Horizontal).width('100%')
    }
    if (this.item.photoIds.length < 6) {
      Row({ space: 8 }) { ActionButton({ label: '拍照', run: () => this.photos(true) }); ActionButton({ label: '从相册选', run: () => this.photos(false) }); ActionButton({ label: '语音填写名称', run: ()=>{if(!this.voiceOpen){this.voiceTarget='名称';this.voiceOpen=true;}} }); }.enabled(!this.busy)
    }
    if (this.busy) { LoadingProgress().width(28).height(28); Text('正在处理照片或保存…').fontSize(14) }
    if (this.item.photoIds.length >= 6) { ActionButton({ label: '语音填写名称', run: ()=>{if(!this.voiceOpen){this.voiceTarget='名称';this.voiceOpen=true;}} }) }
    MenuRow({ title: '放在哪里', subtitle: this.repository.path(this.item.locationId) || '稍后也能补充', action: () => this.choosingLocation = true })
    MenuRow({ title: '日期', subtitle: [this.resultDate() ? '到期 ' + this.resultDate() : '', this.dateValue('WARRANTY') ? '保修 ' + this.dateValue('WARRANTY') : '', this.item.status === 'LENT' && this.dateValue('RETURN') ? '归还 ' + this.dateValue('RETURN') : ''].filter((value: string) => !!value).join(' · ') || '到期、保修，按需记下', action: () => this.datesOpen = !this.datesOpen })
    if (this.datesOpen) { this.dates() }
    ActionButton({ label: this.more ? '收起更多信息' : '更多信息 · 数量、说明', run: () => this.more = !this.more })
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
      Text(this.item.kind === 'GROUP' ? '这组里面有什么' : '说明').fontSize(14).fontColor($r('app.color.secondary')).width('100%')
      ActionButton({ label: '语音填写说明', run: ()=>{if(!this.voiceOpen){this.voiceTarget='说明';this.voiceOpen=true;}} })
      TextArea({ text: this.item.notes, placeholder: '留一点线索，给下次寻找的自己。' }).maxLength(2000).constraintSize({ minHeight: 100 }).onChange((value: string) => { this.item.notes = value; this.changed(); })
      if (this.item.barcodeValue) { Text('商品条码：' + this.item.barcodeValue).fontSize(14) }
    }
    if (this.item.photoIds.length) { ActionButton({ label: this.recognizing ? '正在提取，可继续编辑或保存' : '提取照片文字', run: () => this.recognize() }) }
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
  @Builder voice() { VoicePanel({target:this.voiceTarget,currentValue:this.voiceTarget==='名称'?this.item.title:this.item.notes,maxLength:this.voiceTarget==='名称'?80:2000,append:this.voiceTarget==='说明',onAdopt:(text:string)=>{if(this.voiceTarget==='名称')this.item.title=text;else this.item.notes=[this.item.notes,text].filter((value:string)=>!!value).join('\n');this.voiceOpen=false;this.changed();},onCancel:()=>this.voiceOpen=false}) }
  build() {
    Column() {
      Row() {
        Text(this.receipt ? '已记下' : this.draft.mode === 'EDIT' ? '编辑物品' : '记下').fontSize(24).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
        Button('关闭').fontColor($r('app.color.secondary')).backgroundColor(Color.Transparent).height(48).onClick(() => { this.persist(); this.onClose(); })
      }.padding({ left: 20, right: 12, top: 12 }).width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (this.receipt) {
            Text('✓').fontSize(52).fontColor($r('app.color.primary')).margin({ top: 30 })
            Text(displayName(this.item)).fontSize(24).fontColor($r('app.color.text'))
            Text(this.repository.path(this.item.locationId) || '随时可以补上位置').fontSize(16).fontColor($r('app.color.secondary'))
            ActionButton({ label: '查看这件', run: () => this.onView(this.receipt) })
            if (this.resultDate() && !this.repository.data.preference.reminderEnabled) { ActionButton({ label: '开启到期提醒', run: () => this.onReminder() }) }
            if (this.draft.mode !== 'EDIT') { ActionButton({ label: '继续记下', primary: true, run: () => this.next() }) }
            ActionButton({ label: '完成这次整理', run: () => this.onClose() })
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
              ActionButton({label:'采用当前记录继续编辑',run:()=>{if(this.conflict){this.item=copy(this.conflict);this.draft.baseRevision=this.item.revision;this.conflict=undefined;this.changed();}}})
              if(!this.conflict.deletedAt){ActionButton({label:'确认用这份草稿保存',run:()=>{if(this.conflict){this.item.revision=this.conflict.revision;this.conflict=undefined;this.save();}}});}
            }
            ActionButton({label:'保留原记录，另存为新记录',run:()=>this.saveAsNew()})
          }
        }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart)
      if (!this.receipt && !this.choosingLocation && !this.previewId) {
        Column({ space: 6 }) {
          if (!this.item.title.trim() && !this.item.photoIds.length) { Text('写个名称，或加张照片').fontSize(13).fontColor($r('app.color.secondary')) }
          Button(this.busy ? '正在保存' : this.draft.mode === 'EDIT' ? '保存修改' : '保存').height(50).width('100%').backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).enabled(!this.busy && (!!this.item.title.trim() || !!this.item.photoIds.length)).onClick(() => this.save())
        }.padding({ left: 20, right: 20, top: 8, bottom: 16 }).backgroundColor($r('app.color.surface'))
      }
      if (this.voiceOpen) { this.voice() }
    }.height('100%').width('100%').backgroundColor($r('app.color.background'))
  }
}
