import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { Repository } from '../data/Repository';
import { Item, ItemDate, displayName, localDate } from '../model/Models';

export class CardLine { id: string = ''; title: string = ''; detail: string = ''; }
export class CardContent { wide: boolean = false; mode: string = 'COMMON'; lines: CardLine[] = []; updated: string = ''; }
export class CardService {
  static content(repository: Repository, wide: boolean): CardContent {
    const data = new CardContent(); data.wide = wide; data.mode = repository.data.preference.cardMode;
    if (!wide || !repository.data.preference.cardSummary) return data;
    const items = repository.data.items.filter((item:Item)=>!item.deletedAt && item.status!=='ARCHIVED');
    if (data.mode === 'DATES') {
      items.forEach((item:Item)=>item.dates.filter((date:ItemDate)=>!date.handledAt).forEach((date:ItemDate)=>{
        const line = new CardLine(); line.id=item.id; line.title=displayName(item); line.detail=date.date+' · '+(date.type==='EXPIRY'?'到期':date.type==='RETURN'?'归还':'保修'); data.lines.push(line);
      }));
      data.lines.sort((a:CardLine,b:CardLine)=>a.detail.localeCompare(b.detail));
    } else {
      repository.data.preference.cardIds.forEach((id:string)=>{ const item=items.find((value:Item)=>value.id===id);if(item){const line=new CardLine();line.id=item.id;line.title=displayName(item);line.detail=repository.path(item.locationId)||'位置待补充';data.lines.push(line);} });
    }
    data.lines=data.lines.slice(0,3);const now=new Date();data.updated=localDate(now)+' '+String(now.getHours()).padStart(2,'0')+':'+String(now.getMinutes()).padStart(2,'0');return data;
  }
  static async refresh(repository:Repository):Promise<void> {
    const forms=await formProvider.getPublishedRunningFormInfos();
    await Promise.all(forms.map(async(form)=>{try{await formProvider.updateForm(form.formId,formBindingData.createFormBindingData(CardService.content(repository,form.dimension===3)));}catch(_){} }));
  }
  static async update(context:common.Context,id:string,dimension:number=0):Promise<void>{const repository=new Repository();await repository.open(context);try{if(!dimension){const info=await formProvider.getPublishedRunningFormInfoById(id);dimension=info.dimension;}await formProvider.updateForm(id,formBindingData.createFormBindingData(CardService.content(repository,dimension===3)));}finally{repository.close();}}
}
