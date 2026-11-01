@Component
export struct ActionButton {
  @Prop label:string='';
  @Prop primary:boolean=false;
  @Prop tonal:boolean=false;
  @Prop danger:boolean=false;
  run:()=>void=()=>{};
  build(){Button(this.label).constraintSize({minHeight:44}).fontSize(15).padding({left:16,right:16}).fontColor(this.primary?$r('app.color.onPrimary'):this.danger?$r('app.color.danger'):$r('app.color.primary')).backgroundColor(this.primary?$r('app.color.primary'):this.tonal?$r('app.color.subtle'):Color.Transparent).onClick(()=>this.run())}
}
@Component
export struct SectionHeading {
  @Prop title:string='';
  @Prop subtitle:string='';
  build(){Column({space:6}){Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'));if(this.subtitle){Text(this.subtitle).fontSize(14).fontColor($r('app.color.secondary'));}}.alignItems(HorizontalAlign.Start).width('100%').padding({top:12,bottom:12})}
}
@Component
export struct MenuRow {
  @Prop title:string='';
  @Prop subtitle:string='';
  action:()=>void=()=>{};
  build(){Row({space:12}){Column({space:6}){Text(this.title).fontSize(17).fontColor($r('app.color.text'));if(this.subtitle){Text(this.subtitle).fontSize(13).fontColor($r('app.color.secondary'));}}.alignItems(HorizontalAlign.Start).layoutWeight(1);Text('›').fontSize(24).fontColor($r('app.color.secondary'));}.width('100%').padding(18).constraintSize({minHeight:68}).backgroundColor($r('app.color.surface')).borderRadius(20).onClick(()=>this.action()).accessibilityLevel('yes').accessibilityText(this.title+'，'+this.subtitle)}
}
