import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { Item, Asset, copy } from '../model/Models';
import { Repository } from '../data/Repository';
import { BackupService, RestorePreview, RestoreConflict } from '../services/BackupService';

@Component
export struct DataPage {
  repository: Repository = new Repository();
  onDone: () => void = () => {};
  @State status: string = '';
  @State busy: boolean = false;
  @State preview?: RestorePreview = undefined;
  @State replace: boolean = false;
  @State agreed: boolean = false;
  @State restoreExpired: boolean = false;
  @State includeArchived: boolean = false;
  @State acceptMissing:boolean=false;
  @State restored: boolean = false;
  @State summary: string = '';
  private service?: BackupService;
  private alive: boolean = true;
  aboutToAppear(): void { this.alive = true; this.repository.maintain(this.getUIContext().getHostContext() as common.UIAbilityContext); this.updateSummary(); this.service = new BackupService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository); this.service.progress = (message: string) => this.status = message; }
  private updateSummary(): void { const data = this.repository.data; this.summary = `${data.items.length} 条记录 · ${data.locations.length} 个位置 · ${data.assets.length} 张照片\n照片约 ${(data.assets.reduce((sum: number, asset: Asset) => sum + asset.byteSize, 0) / 1048576).toFixed(1)} MB；完整备份还包含文字与历史`; }
  private chooseAll(useBackup: boolean): void { if (this.preview) { const preview = copy(this.preview); preview.conflicts.forEach((conflict: RestoreConflict) => conflict.useBackup = useBackup); this.preview = preview; } }
  aboutToDisappear(): void { this.alive = false; if (this.service) this.service.cancelled = true; if (!this.busy) this.service?.cleanup(); }
  private async run(action: () => Promise<string>): Promise<void> { if (this.busy) return; this.busy = true; try { this.status = await action(); } catch (error) { this.status = (error as Error).message; } finally { this.busy = false; if (!this.alive || !this.preview) this.service?.cleanup(); } }
  private async select(protection: boolean = false): Promise<string> { this.preview = protection ? await this.service!.protection() : await this.service!.selectBackup(); this.replace = false; this.agreed = false; this.acceptMissing = false; this.restoreExpired = false; return this.preview ? '文件已校验，请核对恢复范围' : '已取消'; }
  private restore(): void { if (!this.preview) return; const preview = this.preview; if (this.service) this.service.cancelled = false; this.run(async () => { const result = await this.service!.restore(preview, this.replace, this.restoreExpired); this.preview = undefined; this.restored = true; this.updateSummary(); return result; }); }
  @Builder action(label: string, run: () => void) { Button(label).height(48).width('100%').fontColor($r('app.color.primary')).backgroundColor($r('app.color.subtle')).enabled(!this.busy).onClick(run) }
  build() {
    Column({ space: 16 }) {
      Text('为认真记录的生活，\n多留一份底稿。').fontSize(24).fontColor($r('app.color.text'))
      Text('家当与照片保存在这台设备中。完整备份包含照片、位置、借出信息、草稿和历史，请选择自己信任的保存位置。').fontColor($r('app.color.secondary')).fontSize(15)
      Text(this.summary).fontColor($r('app.color.primary'))
      if (this.preview) {
        Text('恢复预览').fontSize(22).fontColor($r('app.color.text'))
        Text(`单件 ${this.preview.manifest.counts.single} 条 · 整组 ${this.preview.manifest.counts.group} 组 · 归档 ${this.preview.manifest.counts.archived} 条 · 回收站 ${this.preview.manifest.counts.trash} 条\n后续保存预留约 ${Math.ceil(this.preview.requiredBytes / 1048576)} MB；替换前还会核对保护快照空间`).fontColor($r('app.color.secondary'))
        if(this.preview.warnings.length){
          ForEach(this.preview.warnings,(warning:string)=>{Text(warning).fontColor($r('app.color.warning'));})
          Text('可重新选择完整备份；也可确认保留文字，之后补充照片。只有照片的记录需先填写名称。').fontColor($r('app.color.secondary'))
          ForEach(this.preview.snapshot.items.filter((item:Item)=>!item.photoIds.length && item.missingPhotoCount>0),(item:Item)=>{TextInput({text:item.title,placeholder:'为照片缺失的记录补充名称'}).maxLength(80).onChange((value:string)=>{const current=this.preview?.snapshot.items.find((entry:Item)=>entry.id===item.id);if(current)current.title=value;});},(item:Item)=>item.id)
          Row(){Checkbox({name:'确认照片待补充'}).select(this.acceptMissing).onChange((value:boolean)=>this.acceptMissing=value);Text('确认导入并稍后补充照片').fontColor($r('app.color.text')).layoutWeight(1);}
        }
        Text(`来源版本 ${this.preview.manifest.appVersion}\n生成于 ${new Date(this.preview.manifest.exportedAt).toLocaleString('zh-CN',{hour12:false})}\n${this.preview.snapshot.items.length} 条记录，${this.preview.snapshot.assets.length} 张照片，${this.preview.snapshot.drafts.length} 条草稿\n预计新增 ${this.preview.newItems} 条，已存在 ${this.preview.existingItems} 条，差异 ${this.preview.conflicts.length} 项`).fontColor($r('app.color.text'))
        Row() { Text('用备份替换当前家当').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.replace }).onChange((value: boolean) => { this.replace = value; this.agreed = false; }) }
        if (this.replace) {
          Text('替换前的数据保留 7 天，可从本页的保护快照恢复。新的替换会更新最近一份保护快照，请先导出需要保留的数据。').fontColor($r('app.color.warning'))
          Row() { Checkbox({ name: '确认替换' }).select(this.agreed).onChange((value: boolean) => this.agreed = value); Text(`确认用备份中的 ${this.preview.snapshot.items.length} 条替换当前 ${this.repository.data.items.length} 条`).fontColor($r('app.color.text')).layoutWeight(1) }
        } else {
          Text('合并到当前家当；冲突默认保留当前版本。').fontColor($r('app.color.secondary'))
          if (this.preview.conflicts.length) { this.action('全部保留当前', () => this.chooseAll(false)); this.action('全部采用备份', () => this.chooseAll(true)); }
          ForEach(this.preview.conflicts, (entry: RestoreConflict, index: number) => {
            Column({ space: 8 }) { Text(entry.title).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')); Text('当前：' + entry.current + '\n备份：' + entry.backup).fontSize(14).fontColor($r('app.color.secondary')); Row() { Text('使用备份版本').fontColor($r('app.color.text')).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: entry.useBackup }).onChange((value: boolean) => { if (this.preview) { this.preview.conflicts[index].useBackup = value; } }) } }.padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)
          }, (entry: RestoreConflict) => entry.kind + entry.id + ':' + entry.useBackup)
        }
        if (this.preview.expired) { Row() { Text(`将 ${this.preview.expired} 条已过回收期限的记录恢复后导入`).layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.restoreExpired }).onChange((value: boolean) => this.restoreExpired = value) } }
        Button('确认恢复').height(50).width('100%').backgroundColor($r('app.color.primary')).fontColor($r('app.color.onPrimary')).enabled(!this.busy && (!this.replace || this.agreed) && (!this.preview.warnings.length || this.acceptMissing)).onClick(() => this.restore())
        this.action('取消预览', () => { this.preview = undefined; this.service?.cleanup(); })
      } else {
        this.action('制作完整备份', () => this.run(() => this.service!.exportBackup()))
        Row() { Text('清单包含归档记录').layoutWeight(1).fontColor($r('app.color.text')); Toggle({ type: ToggleType.Switch, isOn: this.includeArchived }).onChange((value: boolean) => this.includeArchived = value) }
        this.action('导出 CSV 清单', () => this.run(() => this.service!.exportCsv(this.includeArchived)))
        this.action('从完整备份恢复', () => this.run(() => this.select()))
        this.action('查看替换前的保护快照', () => this.run(() => this.select(true)))
        this.action('另存保护快照', () => this.run(() => this.service!.exportProtection()))
      }
      if (this.busy) { LoadingProgress().width(36).height(36); Button('取消当前操作').onClick(() => { if (this.service) this.service.cancelled = true; }) }
      if (this.status) { Text(this.status).fontColor($r('app.color.primary')).fontSize(15).copyOption(CopyOptions.InApp) }
      if (this.restored) { this.action('查看家当', () => this.onDone()) }
      Text('系统备份与换机').fontSize(20).fontColor($r('app.color.text'))
      Text('在系统设置的备份或手机克隆中选择本应用。系统会按设备设置处理数据；手动完整备份可随时保存到你指定的位置。').fontColor($r('app.color.secondary'))
      Text(`诊断预览：应用 1.0.0，系统 ${deviceInfo.osFullName}，API ${deviceInfo.sdkApiVersion}。不包含物品名称、照片、位置或账号信息。`).fontColor($r('app.color.secondary')).fontSize(14)
      this.action('导出上述诊断信息', () => this.run(() => this.service!.exportText('我的家当诊断.txt', `应用 1.0.0\n系统 ${deviceInfo.osFullName}\nAPI ${deviceInfo.sdkApiVersion}\n导出时间 ${new Date().toISOString()}`)))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
