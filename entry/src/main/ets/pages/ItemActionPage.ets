import { PageHeader } from '../components/PageHeader';
import { AppServices } from '../service/AppServices';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { NavigationRouteParams } from '../navigation/RouteContract';
import { nativeTitleOptions } from '../ui/VisualStyle';
import { ExternalRequest } from '../model/SystemFeatures';
import { ItemSummary } from '../model/Item';
import { ItemQuery } from '../model/ItemQuery';
import { Batch } from '../model/Batch';
import { OutstandingLoan } from '../model/TraceEvent';
import { AppEventBus } from '../common/AppEventBus';

@Component
export struct ItemActionPage {
  @StorageLink('itemnest.safeAreaBottom') private bottom: number = 0;
  @StorageLink('itemnest.reduceAnimation') private reduceAnimation: boolean = false;
  @State private items: ItemSummary[] = [];
  @State private batches: Batch[] = [];
  @State private loans: OutstandingLoan[] = [];
  @State private itemId: string = '';
  @State private batchId: string = '';
  @State private borrowId: string = '';
  @State private name: string = '';
  @State private action: string = '';
  @State private quantity: string = '';
  @State private counterpart: string = '';
  @State private busy: boolean = false;
  @State private done: boolean = false;
  @State private message: string = '';
  private generation: number = 0;

  aboutToAppear(): void {
    const request = (NavigationHelper.getParams() as NavigationRouteParams | undefined)?.externalRequest;
    this.action = request?.action ?? '';
    this.name = request?.name ?? '';
    this.quantity = request?.quantity?.toString() ?? '';
    this.counterpart = request?.counterpart ?? '';
    this.find(request);
  }

  aboutToDisappear(): void { this.generation++; }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('请核对物品、数量和相关记录。确认前不会修改库存。').fontSize(14).fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.name, placeholder: '物品名称' }).maxLength(80).enabled(!this.busy && !this.done)
            .onChange((value: string) => this.name = value).onSubmit(() => this.find())
          Button('查找物品').enabled(!this.busy && !this.done).onClick(() => this.find())
          ForEach(this.items, (item: ItemSummary) => {
            Button((this.itemId === item.id ? '已选：' : '') + item.name + ' · ' + item.quantity + item.unit +
              ' · ' + (item.activeLocationPaths?.join('、') || item.locationPath || '未记录位置'))
              .width('100%').height('auto').padding(12).enabled(!this.busy && !this.done)
              .onClick(() => this.selectItem(item.id))
          }, (item: ItemSummary) => item.id)
          if (this.itemId.length > 0) {
            TextInput({ text: this.quantity, placeholder: '本次数量' }).type(InputType.NUMBER_DECIMAL)
              .enabled(!this.busy && !this.done).onChange((value: string) => this.quantity = value)
            if (this.action === 'borrow') {
              TextInput({ text: this.counterpart, placeholder: '借给谁' }).maxLength(80)
                .enabled(!this.busy && !this.done).onChange((value: string) => this.counterpart = value)
            }
            if (this.action === 'return') {
              Text('选择要归还的借出记录').fontSize(15).fontColor($r('app.color.text_primary'))
              ForEach(this.loans, (loan: OutstandingLoan) => {
                Button((this.borrowId === loan.borrowEvent.id ? '已选：' : '') +
                  (loan.borrowEvent.counterpart || '未填写借用人') + ' · 尚欠 ' + loan.remainingQuantity +
                  ' · ' + new Date(loan.borrowEvent.createdAt).toLocaleDateString())
                  .width('100%').height('auto').padding(12).enabled(!this.busy && !this.done)
                  .onClick(() => { this.borrowId = loan.borrowEvent.id; this.batchId = loan.borrowEvent.batchId ?? ''; })
              }, (loan: OutstandingLoan) => loan.borrowEvent.id)
            } else {
              Text('选择批次').fontSize(15).fontColor($r('app.color.text_primary'))
              ForEach(this.batches, (batch: Batch) => {
                Button((this.batchId === batch.id ? '已选：' : '') + batch.quantity + batch.unit + ' · ' +
                  (batch.locationPath || '默认位置') + ' · ' + (batch.expirationDate || '无到期日'))
                  .width('100%').height('auto').padding(12).enabled(!this.busy && !this.done)
                  .onClick(() => this.batchId = batch.id)
              }, (batch: Batch) => batch.id)
            }
          }
          if (this.message.length > 0) { Text(this.message).fontSize(14).fontColor($r('app.color.text_secondary')) }
          Button(this.done ? '已完成' : this.busy ? '正在处理…' : '确认' + this.title())
            .enabled(!this.busy && !this.done && this.itemId.length > 0).onClick(() => this.confirm())
        }.width('100%').constraintSize({ maxWidth: 760 }).padding(24).alignItems(HorizontalAlign.Start)
      }.align(Alignment.TopStart).width('100%').height('100%').padding({ bottom: this.bottom })
    }.title({ builder: this.header, height: 76 }, nativeTitleOptions(this.reduceAnimation))
      .hideBackButton(true).backgroundColor($r('app.color.surface_app'))
  }

  private title(): string { return this.action === 'consume' ? '记录消耗' : this.action === 'borrow' ? '记录借出' : '记录归还'; }
  @Builder
  private header() { PageHeader({ title: this.title(), subtitle: '核对后再保存。', showBack: true }) }

  private async find(request?: ExternalRequest): Promise<void> {
    this.busy = true; this.message = ''; this.itemId = ''; this.borrowId = ''; this.batchId = '';
    const generation = ++this.generation;
    try {
      const result = await AppServices.get().searchItems.search(new ItemQuery(this.name));
      if (generation !== this.generation) { return; }
      if (!result.ok) { this.message = result.getError().message; return; }
      this.items = result.getData().items;
      const candidate = this.items.find((item: ItemSummary) => item.id === request?.itemId);
      if (candidate !== undefined) { await this.selectItem(candidate.id); }
      else if (this.items.length === 1) { await this.selectItem(this.items[0].id); }
      else { this.message = this.items.length === 0 ? '没有找到物品，请修改名称再查找。' : '找到多个物品，请选择本次操作的物品。'; }
    } catch (_) { this.message = '读取物品失败，请重试'; }
    finally { if (generation === this.generation) { this.busy = false; } }
  }

  private async selectItem(id: string): Promise<void> {
    this.busy = true; this.itemId = id; this.batchId = ''; this.borrowId = ''; this.batches = []; this.loans = [];
    try {
      const batches = await AppServices.get().batches.listByItemId(id);
      const state = await AppServices.get().lending.getState(id);
      if (!batches.ok) { throw batches.getError(); }
      if (!state.ok) { throw state.getError(); }
      this.batches = batches.getData().filter((batch: Batch) => batch.quantity > 0);
      this.loans = state.getData().outstandingLoans;
      if (this.action === 'return') {
        const matches = this.loans.filter((loan: OutstandingLoan) => this.counterpart.length === 0 ||
          loan.borrowEvent.counterpart === this.counterpart);
        if (matches.length === 1) {
          this.borrowId = matches[0].borrowEvent.id; this.batchId = matches[0].borrowEvent.batchId ?? '';
        }
      } else if (this.batches.length === 1) { this.batchId = this.batches[0].id; }
      this.message = '当前可用 ' + state.getData().availableQuantity + state.getData().unit;
    } catch (_) { this.itemId = ''; this.message = '读取库存或借还记录失败，请重试'; }
    finally { this.busy = false; }
  }

  private async confirm(): Promise<void> {
    if (this.busy || this.done || !['consume', 'borrow', 'return'].includes(this.action)) { return; }
    if (!Number.isFinite(Number(this.quantity)) || Number(this.quantity) <= 0) { this.message = '请填写大于零的数量'; return; }
    if (this.action === 'return' ? this.borrowId.length === 0 : this.batchId.length === 0) {
      this.message = this.action === 'return' ? '请选择对应的借出记录' : '请选择本次操作的批次'; return;
    }
    this.busy = true;
    try {
      const services = AppServices.get();
      if (this.action === 'consume') {
        const result = await services.batches.consume(this.itemId, Number(this.quantity), this.batchId);
        if (!result.ok) { this.message = result.getError().message; return; }
      } else {
        const result = this.action === 'borrow' ?
          await services.lending.borrow(this.itemId, Number(this.quantity), this.counterpart, this.batchId) :
          await services.lending.returnItem(this.itemId, Number(this.quantity), this.batchId || undefined, undefined, this.borrowId);
        if (!result.ok) { this.message = result.getError().message; return; }
      }
      this.done = true;
      AppEventBus.notifyDataChanged();
      this.message = '已保存';
      try {
        const reminder = await services.reminders.reconcileLatest(this.itemId);
        if (!reminder.ok) { this.message = '已保存，提醒更新失败，可在详情重试'; }
      } catch (_) { this.message = '已保存，提醒更新失败，可在详情重试'; }
    } catch (_) { this.message = '保存失败，请重试'; }
    finally { this.busy = false; }
  }
}
