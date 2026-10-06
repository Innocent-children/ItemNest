import { InventoryMetrics } from '../components/InventoryMetrics';
import { PageHeader } from '../components/PageHeader';
import { RoundedButtonStyle, uiSpring, nativeTitleOptions, nativeSheetOptions } from '../ui/VisualStyle';
import { LendingRouteParams } from '../navigation/RouteContract';
import { NavigationHelper } from '../navigation/NavigationHelper';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { LatestRequestCoordinator } from '../common/LatestRequestCoordinator';
import { ItemUnit } from '../model/Item';
import { OutstandingLoan, ReturnAllocation, TraceEvent, TraceEventType } from '../model/TraceEvent';
import { BatchRouteParams, requireItemId } from '../navigation/RouteContract';
import { AppServices } from '../service/AppServices';

@Component
export struct LendingPage {
  @State private viewportWidth: number = 360;
  @State private showOperationSheet: boolean = false;
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @StorageLink('itemtrace.safeAreaLeft') private safeAreaLeft: number = 0;
  @StorageLink('itemtrace.safeAreaRight') private safeAreaRight: number = 0;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private focusedField: string = '';
  @State private loading: boolean = true;
  @State private contentLoaded: boolean = false;
  @State private submitting: boolean = false;
  @State private loadError: string = '';
  @State private actionError: string = '';
  @State private quantityText: string = '1';
  @State private counterpart: string = '';
  @State private note: string = '';
  @State private itemName: string = '';
  @State private unit: ItemUnit = ItemUnit.PIECE;
  @State private totalQuantity: number = 0;
  @State private availableQuantity: number = 0;
  @State private borrowedQuantity: number = 0;
  @State private inventoryWarning: string = '';
  @State private outstandingLoans: OutstandingLoan[] = [];
  @State private events: TraceEvent[] = [];
  @State private formMode: string = 'borrow';
  @State private selectedBorrowId: string = '';
  @State private editEventId: string = '';
  private itemId: string = '';
  private initialBorrowEventId: string = '';
  private lastHandledDataRevision: number = -1;
  private loadRequests: LatestRequestCoordinator = new LatestRequestCoordinator();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as BatchRouteParams | undefined;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loadError = itemIdResult.getError().message;
      this.loading = false;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.initialBorrowEventId = (params as LendingRouteParams | undefined)?.borrowEventId ?? '';
    this.loadStateForCurrentRevision(true);
  }

  aboutToDisappear(): void {
    this.loadRequests.invalidate();
  }

  onPageShow(): void {
    if (this.itemId.length > 0) {
      this.refreshForRevisionChange(false);
    }
  }

  private onDataRevisionChanged(): void {
    if (this.itemId.length > 0) {
      this.refreshForRevisionChange(false);
    }
  }

  private refreshForRevisionChange(showLoading: boolean = false): boolean {
    const dataRevision = AppEventBus.currentDataRevision();
    if (dataRevision === this.lastHandledDataRevision) {
      return false;
    }
    this.loadStateForCurrentRevision(showLoading);
    return true;
  }

  private loadStateForCurrentRevision(showLoading: boolean = true): void {
    this.lastHandledDataRevision = AppEventBus.currentDataRevision();
    this.loadState(showLoading);
  }

  build() {
    NavDestination() {
      this.pageContent()
    }
    .title({ builder: this.pageHeader, height: 76 }, nativeTitleOptions(this.reduceAnimation))
    .hideBackButton(true)
    .bindToScrollable([this.scroller])
    .backgroundColor($r('app.color.surface_app'))
    .onBackPressed(() => NavigationHelper.handleBackPressed())
  }

  @Builder
  private pageHeader() {
    PageHeader({ title: '借出与归还', subtitle: '记清借给谁，也记得收回来。', showBack: true })
  }

  @Builder
  private pageContent() {
    Column() {

      if (this.loading) {
        LoadingState({ text: '正在读取借还记录…' })
      } else if (!this.contentLoaded && this.loadError.length > 0) {
        ErrorState({ message: this.loadError })
        Button('重新加载')
          .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onClick(() => this.loadStateForCurrentRevision(true))
      } else {
        Scroll(this.scroller) {
          Column({ space: $r('app.float.space_4') }) {
            Column({ space: $r('app.float.space_2') }) {
              Text(this.itemName)
                .fontSize($r('app.float.font_section'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              InventoryMetrics({ total: this.totalQuantity, available: this.availableQuantity,
                borrowed: this.borrowedQuantity, unit: this.unit })
              Text('归还只增加在手，总量保持不变。').fontSize(12).fontColor($r('app.color.text_secondary'))
              if (this.inventoryWarning.length > 0) {
                Text(this.inventoryWarning)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_danger'))
              }
            }
            .width('100%').alignItems(HorizontalAlign.Start)
            .padding(24)
            .backgroundColor($r('app.color.surface_card'))
            .borderRadius($r('app.float.radius_card'))

            Row({ space: $r('app.float.space_2') }) {
              Button('记录借出')
                .fontColor($r('app.color.brand_on_primary')).backgroundColor($r('app.color.brand_primary'))
                .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .layoutWeight(1)
                .enabled(!this.submitting)
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onClick(() => { this.startBorrow(); this.showOperationSheet = true; })
              Button('记录归还')
                .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_card'))
                .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .layoutWeight(1)
                .enabled(!this.submitting && this.outstandingLoans.length > 0)
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onClick(() => { this.startReturn(); this.showOperationSheet = true; })
            }
            .width('100%')

            if (this.actionError.length > 0) {
              ErrorState({ message: this.actionError })
            }
            if (this.loadError.length > 0) {
              ErrorState({ message: this.loadError })
              Button('重新加载')
                .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                .onClick(() => this.loadStateForCurrentRevision(false))
            }

            Text('尚未归还').width('100%')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            if (this.outstandingLoans.length === 0) {
              Text('目前没有待归还的借出记录')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
            }
            ForEach(this.outstandingLoans, (loan: OutstandingLoan) => {
              Column({ space: $r('app.float.space_2') }) {
                Text(this.loanLabel(loan))
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                if (loan.borrowEvent.note !== undefined) {
                  Text(`备注：${loan.borrowEvent.note}`)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                Button('归还这笔')
                  .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
                  .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
                  .enabled(!this.submitting)
                  .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
                  .onClick(() => { this.startReturn(loan); this.showOperationSheet = true; })
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (loan: OutstandingLoan) => `${loan.borrowEvent.id}-${loan.remainingQuantity}-${loan.borrowEvent.counterpart ?? ''}-${loan.borrowEvent.note ?? ''}`)

            Text('操作记录').width('100%')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            ForEach(this.events, (event: TraceEvent) => {
              this.eventCard(event)
            }, (event: TraceEvent) => `${event.id}-${event.quantity}-${event.voidedAt ?? 0}-${event.note ?? ''}-${event.counterpart ?? ''}-${JSON.stringify(event.returnAllocations ?? [])}`)
          }
          .width('100%')
          .padding({ left: $r('app.float.page_gutter'), right: $r('app.float.page_gutter'), bottom: $r('app.float.space_6') })
        }
        .clip(false).align(Alignment.TopStart)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%').constraintSize({ maxWidth: 960 })
    .padding({ bottom: this.safeAreaBottom, left: this.safeAreaLeft, right: this.safeAreaRight })
    .backgroundColor($r('app.color.surface_app'))
    .onAreaChange((_old: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.showOperationSheet, this.operationSheet(), nativeSheetOptions({
      height: SheetSize.LARGE, dragBar: true, showClose: true,
      title: { title: this.formTitle() }, preferType: this.viewportWidth >= 700 ? SheetType.CENTER : SheetType.BOTTOM,
      width: this.viewportWidth >= 700 ? 560 : undefined,
      backgroundColor: $r('app.color.surface_app'),
      onWillDismiss: (action: DismissSheetAction) => { if (!this.submitting) { action.dismiss(); } }
    }, this.reduceAnimation))
  }

  @Builder
  private operationSheet() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.isReturnForm()) {
          Text(this.formMode === 'editReturn' ? '归还来源保持原关联；选中其他借出可纠正归还对象。' : '选择这次归还对应的借出记录')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          ForEach(this.returnCandidates(), (loan: OutstandingLoan) => {
            Button(`${this.selectedBorrowId === loan.borrowEvent.id ? '✓ ' : ''}${this.loanLabel(loan)}`)
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .width('100%')
              .enabled(!this.submitting)
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => {
                this.selectedBorrowId = loan.borrowEvent.id;
              })
          }, (loan: OutstandingLoan) => `${loan.borrowEvent.id}-${loan.remainingQuantity}-${loan.borrowEvent.counterpart ?? ''}-${loan.borrowEvent.note ?? ''}`)
        } else {
          TextInput({ text: this.counterpart, placeholder: '借给谁，可选' })
            .borderWidth(1)
            .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'counterpart'))
            .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
              if (this.focusedField === 'counterpart') { this.focusedField = ''; }
            }))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 1, color: $r('app.color.border_subtle') })
            .borderRadius($r('app.float.radius_control'))
            .enabled(!this.submitting)
            .borderColor(this.focusedField === 'counterpart' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onChange((value: string) => this.counterpart = value)
        }
        Text(`数量（${this.unit}）`).fontSize(14).fontColor($r('app.color.text_primary'))
        TextInput({ text: this.quantityText, placeholder: `数量（${this.unit}）` })
          .borderWidth(1)
          .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'quantityText'))
          .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
            if (this.focusedField === 'quantityText') { this.focusedField = ''; }
          }))
          .type(InputType.NUMBER_DECIMAL)
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.submitting)
          .borderColor(this.focusedField === 'quantityText' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onChange((value: string) => this.quantityText = value)
        TextInput({ text: this.note, placeholder: '备注，可选' })
          .borderWidth(1)
          .onFocus(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => this.focusedField = 'note'))
          .onBlur(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation, 0.32, 0.62), () => {
            if (this.focusedField === 'note') { this.focusedField = ''; }
          }))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 1, color: $r('app.color.border_subtle') })
          .borderRadius($r('app.float.radius_control'))
          .enabled(!this.submitting)
          .borderColor(this.focusedField === 'note' ? $r('app.color.brand_primary') : $r('app.color.border_subtle'))
          .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
          .onChange((value: string) => this.note = value)
        Row({ space: $r('app.float.space_2') }) {
          if (this.editEventId.length > 0 || this.isReturnForm()) {
            Button('取消')
              .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
              .layoutWeight(1)
              .enabled(!this.submitting)
              .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
              .onClick(() => this.showOperationSheet = false)
          }
          Button(this.submitting ? '正在保存…' : this.editEventId.length > 0 ? '保存纠正' : this.isReturnForm() ? '确认归还' : '确认借出')
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .layoutWeight(1)
            .fontColor($r('app.color.brand_on_primary'))
            .backgroundColor($r('app.color.brand_primary'))
            .borderRadius($r('app.float.radius_control'))
            .enabled(!this.submitting && this.loadError.length === 0)
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.saveOperation())
        }
        .width('100%')
        if (this.actionError.length > 0) { ErrorState({ message: this.actionError }) }
      }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
    }.width('100%')
  }

  @Builder
  private eventCard(event: TraceEvent) {
    Column({ space: $r('app.float.space_1') }) {
      Text(`${this.eventLabel(event.type)} ${event.quantity}${this.unit}${event.voidedAt === undefined ? '' : ' · 已撤销'}`)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(`${new Date(event.createdAt).toLocaleString()}${event.counterpart === undefined ? '' : ` · ${event.counterpart}`}`)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      if (event.note !== undefined) {
        Text(`备注：${event.note}`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (event.type === TraceEventType.RETURN) {
        Text(this.returnSourceLabel(event))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
        if (event.legacyAllocated === true) {
          Text('历史归还按先借先还自动对应，请核对借用人；可用“纠正”重新指定。')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      if (event.voidedAt === undefined && (event.type === TraceEventType.BORROW || event.type === TraceEventType.RETURN)) {
        Row({ space: $r('app.float.space_2') }) {
          Button('纠正')
            .fontColor($r('app.color.brand_primary')).backgroundColor($r('app.color.surface_accent'))
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .enabled(!this.submitting)
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => { this.startCorrection(event); this.showOperationSheet = true; })
          Button('撤销')
            .fontColor($r('app.color.text_secondary')).backgroundColor($r('app.color.surface_input'))
            .attributeModifier(new RoundedButtonStyle(this.reduceAnimation))
            .enabled(!this.submitting)
            .animation(uiSpring(this.reduceAnimation, 0.32, 0.62))
            .onClick(() => this.confirmVoid(event))
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius($r('app.float.radius_control'))
  }

  private async loadState(showLoading: boolean = true): Promise<void> {
    const requestId = this.loadRequests.begin();
    if (showLoading) {
      this.loading = true;
      this.loadError = '';
    }
    try {
      const state = await AppServices.get().lending.getState(this.itemId);
      const events = await AppServices.get().lending.getEvents(this.itemId);
      if (!this.loadRequests.isCurrent(requestId)) {
        return;
      }
      if (!state.ok) {
        this.loadError = state.getError().message;
      } else if (!events.ok) {
        this.loadError = events.getError().message;
      } else {
        this.itemName = state.getData().itemName;
        this.unit = state.getData().unit;
        this.totalQuantity = state.getData().totalQuantity;
        this.availableQuantity = state.getData().availableQuantity;
        this.borrowedQuantity = state.getData().borrowedQuantity;
        this.inventoryWarning = state.getData().inventoryWarning ?? '';
        this.outstandingLoans = state.getData().outstandingLoans;
        this.events = events.getData();
        this.contentLoaded = true;
        this.loadError = '';
        if (this.initialBorrowEventId.length > 0) {
          const loan = this.outstandingLoans.find((value: OutstandingLoan) => value.borrowEvent.id === this.initialBorrowEventId);
          this.initialBorrowEventId = '';
          if (loan !== undefined) { this.startReturn(loan); this.showOperationSheet = true; }
          else { this.actionError = '这笔借出已归还或撤销，列表已更新。'; }
        }
      }
    } catch (_) {
      if (this.loadRequests.isCurrent(requestId)) {
        this.loadError = '读取借还记录失败，请稍后重试';
      }
    } finally {
      if (this.loadRequests.isCurrent(requestId)) {
        this.loading = false;
      }
    }
  }

  private startBorrow(): void {
    this.formMode = 'borrow';
    this.editEventId = '';
    this.selectedBorrowId = '';
    this.quantityText = '1';
    this.counterpart = '';
    this.note = '';
    this.actionError = '';
  }

  private startReturn(loan?: OutstandingLoan): void {
    this.startBorrow();
    this.formMode = 'return';
    const selected = loan ?? (this.outstandingLoans.length === 1 ? this.outstandingLoans[0] : undefined);
    this.selectedBorrowId = selected?.borrowEvent.id ?? '';
    this.quantityText = selected?.remainingQuantity.toString() ?? '1';
    this.scroller.scrollEdge(Edge.Top);
  }

  private startCorrection(event: TraceEvent): void {
    this.editEventId = event.id;
    this.formMode = event.type === TraceEventType.RETURN ? 'editReturn' : 'editBorrow';
    this.selectedBorrowId = event.returnAllocations?.length === 1 ? event.returnAllocations[0].borrowEventId : '';
    this.quantityText = event.quantity.toString();
    this.counterpart = event.counterpart ?? '';
    this.note = event.note ?? '';
    this.actionError = '';
    this.scroller.scrollEdge(Edge.Top);
  }

  private async saveOperation(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.formMode === 'return' && this.selectedBorrowId.length === 0) {
      this.actionError = '请选择这次归还对应的借出记录';
      return;
    }
    this.submitting = true;
    this.actionError = '';
    try {
      const lending = AppServices.get().lending;
      const quantity = Number(this.quantityText);
      const selected = this.selectedBorrowId.length > 0 ? this.selectedBorrowId : undefined;
      const result = this.editEventId.length > 0 ?
        await lending.correctEvent(this.itemId, this.editEventId, quantity, this.counterpart, this.note, selected) :
        this.isReturnForm() ? await lending.returnItem(this.itemId, quantity, undefined, this.note, selected) :
          await lending.borrow(this.itemId, quantity, this.counterpart, undefined, this.note);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      const message = this.editEventId.length > 0 ? '记录已纠正' : this.isReturnForm() ? '归还已记录' : '借出已记录';
      this.showOperationSheet = false;
      this.startBorrow();
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadState(false);
      this.showToast(message);
    } catch (_) {
      this.actionError = '保存失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  private async confirmVoid(event: TraceEvent): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.actionError = '';
    try {
      const confirm = await this.getUIContext().getPromptAction().showDialog({
        title: `撤销这笔${this.eventLabel(event.type)}？`,
        message: `${event.quantity}${this.unit}${event.counterpart === undefined ? '' : ` · ${event.counterpart}`}。撤销后重新计算未归还和在手数量，原记录仍保留并标记为已撤销。`,
        buttons: [{ text: '取消', color: $r('app.color.text_secondary') }, { text: '确认撤销', color: $r('app.color.status_danger') }]
      });
      if (confirm.index !== 1) {
        return;
      }
      const result = await AppServices.get().lending.voidEvent(this.itemId, event.id);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      if (this.editEventId === event.id) {
        this.startBorrow();
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadState(false);
      this.showToast('记录已撤销');
    } catch (_) {
      this.actionError = '撤销失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  private isReturnForm(): boolean {
    return this.formMode === 'return' || this.formMode === 'editReturn';
  }

  private formTitle(): string {
    return this.formMode === 'editBorrow' ? '纠正借出记录' : this.formMode === 'editReturn' ? '纠正归还记录' :
      this.formMode === 'return' ? '记录归还' : '记录借出';
  }

  private loanLabel(loan: OutstandingLoan): string {
    return `${loan.borrowEvent.counterpart ?? '未填写借用人'} · 未归还 ${loan.remainingQuantity}${this.unit} · ${new Date(loan.borrowEvent.createdAt).toLocaleString()}`;
  }

  private returnCandidates(): OutstandingLoan[] {
    const candidates: OutstandingLoan[] = this.outstandingLoans.map((loan: OutstandingLoan): OutstandingLoan => {
      return { borrowEvent: loan.borrowEvent, remainingQuantity: loan.remainingQuantity };
    });
    if (this.formMode !== 'editReturn') {
      return candidates;
    }
    const original = this.events.find((event: TraceEvent) => event.id === this.editEventId);
    const allocations = original?.returnAllocations ?? [];
    for (let index = 0; index < allocations.length; index++) {
      const allocation = allocations[index];
      const found = candidates.find((loan: OutstandingLoan) => loan.borrowEvent.id === allocation.borrowEventId);
      if (found !== undefined) {
        found.remainingQuantity += allocation.quantity;
      } else {
        const borrow = this.events.find((event: TraceEvent) => event.id === allocation.borrowEventId && event.voidedAt === undefined);
        if (borrow !== undefined) {
          candidates.push({ borrowEvent: borrow, remainingQuantity: allocation.quantity });
        }
      }
    }
    return candidates;
  }

  private returnSourceLabel(event: TraceEvent): string {
    const allocations = event.returnAllocations ?? [];
    const sources = allocations.map((allocation: ReturnAllocation) => {
      const borrow = this.events.find((candidate: TraceEvent) => candidate.id === allocation.borrowEventId);
      return `${borrow?.counterpart ?? '未填写借用人'} ${allocation.quantity}${this.unit}（${new Date(borrow?.createdAt ?? event.createdAt).toLocaleString()} 借出）`;
    });
    return sources.length === 0 ? '尚未对应借出，请核对后纠正' : `对应借出：${sources.join('；')}`;
  }

  private eventLabel(type: TraceEventType): string {
    return type === TraceEventType.BORROW ? '借出' : type === TraceEventType.RETURN ? '归还' :
      type === TraceEventType.CONSUME ? '用掉' : '记录';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1600 });
    } catch (_) {
    }
  }
}
