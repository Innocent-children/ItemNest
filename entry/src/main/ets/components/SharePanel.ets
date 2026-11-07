import { PhotoViewer } from './PhotoViewer';
import { common } from '@kit.AbilityKit';
import { Draft, Item, Location, copy, displayName } from '../model/Models';
import { Repository } from '../data/Repository';
import { MediaService } from '../services/MediaService';

@Component
export struct SharePanel {
  repository: Repository = new Repository();
  initial: Draft = new Draft();
  registerBack: (handler?: () => boolean) => void = () => {};
  onClose: () => void = () => {};
  onView: (id: string) => void = () => {};
  @State draft: Draft = new Draft();
  @State error: string = '';
  @State receipt: string[] = [];
  @State busy: boolean = false;
  @State preview: string = '';
  private saveTimer: number = -1;
  @StorageProp('backgroundAt') @Watch('flushInput') backgroundAt: number = 0;
  aboutToAppear(): void {
    this.draft = copy(this.initial);
    this.registerBack(() => {
      if (!this.preview) return false;
      this.preview = '';
      return true;
    });
  }
  aboutToDisappear(): void { this.registerBack(undefined); this.flushInput(); }
  private queueInput(): void {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.flushInput(), 500);
  }
  private flushInput(): void {
    if (this.saveTimer < 0) return;
    clearTimeout(this.saveTimer);
    this.saveTimer = -1;
    this.persist();
  }
  private persist(): void { clearTimeout(this.saveTimer); this.saveTimer = -1; if (!this.receipt.length) { this.draft = copy(this.draft); this.repository.saveDraft(this.draft); } }
  private save(): void {
    if(this.busy || this.receipt.length) return; this.busy = true;
    try {
      const items = copy(this.draft.sharedItems);
      if(this.draft.shareAsGroup) {
        if(items.length>6) throw new Error('整组最多 6 张，请移除部分照片或选择每张记一件');
        const group = copy(this.draft.payload); group.kind = 'GROUP'; group.photoIds = Array.from(new Set(items.flatMap((item:Item)=>item.photoIds)));
        this.receipt = this.repository.saveShared(this.draft,[group]);
      } else { items.forEach((item:Item)=>item.locationId=this.draft.payload.locationId);this.receipt=this.repository.saveShared(this.draft,items); }
    } catch(error) { this.error=(error as Error).message; } finally { this.busy=false; }
  }
  build() {
    Column({space:12}) {
      Row() { Text(this.receipt.length?'已记下':'把照片记进家当').fontSize(23).fontColor($r('app.color.text')).layoutWeight(1);Button('关闭').onClick(()=>{this.persist();this.onClose();}); }.width('100%')
      Scroll() {
        Column({space:14}) {
          if(this.receipt.length) {
            Text(`已保存 ${this.receipt.length} 条记录`).fontSize(24).fontColor($r('app.color.primary'))
            ForEach(this.repository.data.items.filter((item: Item) => this.receipt.includes(item.id)), (item: Item) => { Button('查看：' + displayName(item)).onClick(() => this.onView(item.id)) }, (item: Item) => item.id)
            Button('返回上一个应用').onClick(() => (this.getUIContext().getHostContext() as common.UIAbilityContext).terminateSelf().catch(() => this.error = '可使用系统返回手势回到原应用'))
          } else if (this.preview) {
            PhotoViewer({ repository: this.repository, ids: Array.from(new Set(this.draft.sharedItems.map((item: Item) => item.photoIds[0]))),
              initialId: this.preview, onSelect: (id: string) => this.preview = id })
            Button('返回图片列表').onClick(() => this.preview = '')
          } else {
            Text(`来源 ${this.draft.shareSourceCount} 张，当前 ${this.draft.sharedItems.length} 张。确认后才会记入家当。`).fontColor($r('app.color.secondary'))
            Row({space:8}) {
              Button(this.draft.shareAsGroup?'每张记一件':'✓ 每张记一件').onClick(()=>{this.draft.shareAsGroup=false;this.persist();})
              Button(this.draft.shareAsGroup?'✓ 合成一组':'合成一组').onClick(()=>{this.draft.shareAsGroup=true;this.persist();})
            }
            if(this.draft.shareAsGroup){TextInput({text:this.draft.payload.title,placeholder:'整组名称 · 选填'}).maxLength(80).onChange((value:string)=>{this.draft.payload.title=value;this.queueInput();});}
            if (this.draft.shareAsGroup) { TextArea({ text: this.draft.payload.notes, placeholder: '这组里面有什么 · 选填' }).maxLength(2000).onChange((value: string) => { this.draft.payload.notes = value; this.persist(); }); if (this.draft.sharedItems.length > 6) { Text('整组最多 6 张，请移除部分图片或选择每张记一件').fontColor($r('app.color.warning')) } }
            Select([{value:'位置待补充'},...this.repository.data.locations.map((node:Location):SelectOption=>({value:this.repository.path(node.id)}))]).value(this.repository.path(this.draft.payload.locationId)||'位置待补充').onSelect((index:number)=>{this.draft.payload.locationId=index?this.repository.data.locations[index-1].id:'';this.persist();})
            ForEach(this.draft.sharedItems,(item:Item)=>{
              Row({space:12}) {
                Image(new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext,this.repository).uri(item.photoIds[0],true)).width(80).height(80).objectFit(ImageFit.Cover).borderRadius(12).onClick(() => { this.preview = item.photoIds[0]; })
                Column({space:8}) {
                  if(!this.draft.shareAsGroup){TextInput({text:item.title,placeholder:'名称 · 选填'}).maxLength(80).onChange((value:string)=>{const current=this.draft.sharedItems.find((entry:Item)=>entry.id===item.id);if(current)current.title=value;this.queueInput();});}
                  Button('移除此图').onClick(()=>{this.draft.sharedItems=this.draft.sharedItems.filter((value:Item)=>value.id!==item.id);this.persist();})
                }.layoutWeight(1)
              }.width('100%')
            },(item:Item)=>item.id)
          }
          if(this.error){Text(this.error).fontColor($r('app.color.danger'));}
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .layoutWeight(1).width('100%')
      if(!this.receipt.length){Button(this.draft.shareAsGroup ? '保存这组' : `保存 ${this.draft.sharedItems.length} 条记录`).width('100%').height(50).backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).enabled(!this.busy&&this.draft.sharedItems.length>0&&(!this.draft.shareAsGroup||this.draft.sharedItems.length<=6)).onClick(()=>this.save());}
    }.padding(20).width('100%').height('100%').backgroundColor($r('app.color.background'))
  }
}
