import { CardLine } from '../services/CardService';

const storage = new LocalStorage();
@Entry(storage)
@Component
struct NestCard {
  @LocalStorageProp('wide') wide:boolean=false;
  @LocalStorageProp('mode') mode:string='COMMON';
  @LocalStorageProp('lines') lines:CardLine[]=[];
  @LocalStorageProp('updated') updated:string='';
  build() {
    Column({space:4}) {
      Text('我的家当').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).width('100%')
      if(this.wide && this.lines.length) {
        ForEach(this.lines,(line:CardLine)=>{
          Row({space:8}) {
            Text(line.title).fontSize(13).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).fontColor($r('app.color.text')).layoutWeight(1)
            Text(line.detail).fontSize(11).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).fontColor($r('app.color.secondary')).layoutWeight(1)
          }.width('100%').onClick(()=>postCardAction(this,{action:'router',abilityName:'EntryAbility',params:{action:this.mode==='DATES'?'dates':'item',itemId:line.id}}))
        },(line:CardLine)=>line.id+line.detail)
      } else { Text('记住放哪\n用好已有').fontSize(16).fontColor($r('app.color.primary')).layoutWeight(1).width('100%') }
      Row({space:8}) {
        Button('找东西').fontSize(14).height(48).layoutWeight(1).backgroundColor($r('app.color.subtle')).fontColor($r('app.color.primary')).onClick(()=>postCardAction(this,{action:'router',abilityName:'EntryAbility',params:{action:'search'}}))
        Button('记一件').fontSize(14).height(48).layoutWeight(1).backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).onClick(()=>postCardAction(this,{action:'router',abilityName:'EntryAbility',params:{action:'capture'}}))
      }.width('100%')
      if(this.wide && this.updated){Text('更新于 '+this.updated).fontSize(9).fontColor($r('app.color.secondary')).width('100%');}
    }.padding(10).width('100%').height('100%').backgroundColor($r('app.color.background'))
  }
}
