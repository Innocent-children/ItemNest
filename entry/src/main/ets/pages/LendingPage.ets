import { NavigationHelper } from '../navigation/NavigationHelper';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { AppEventBus } from '../common/AppEventBus';
import { TraceEvent, TraceEventType } from '../model/TraceEvent';
import { BatchRouteParams, requireItemId } from '../navigation/RouteContract';
import { AppServices } from '../service/AppServices';

@Component
export struct LendingPage {
  @StorageLink('itemtrace.dataRevision') @Watch('onDataRevisionChanged') private dataRevision: number = 0;
  @StorageLink('itemtrace.safeAreaTop') private safeAreaTop: number = 0;
  @StorageLink('itemtrace.safeAreaBottom') private safeAreaBottom: number = 0;
  @State private loading: boolean = true;
  @State private contentLoaded: boolean = false;
  @State private submitting: boolean = false;
  @State private loadError: string = '';
  @State private actionError: string = '';
  @State private pressedAction: string = '';
  @State private quantityText: string = '1';
  @State private counterpart: string = '';
  @State private note: string = '';
  @State private borrowedQuantity: number = 0;
  @State private events: TraceEvent[] = [];
  private itemId: string = '';
  private lastHandledDataRevision: number = -1;

  aboutToAppear(): void {
    const params = NavigationHelper.getParams() as BatchRouteParams | undefined;
    const itemIdResult = requireItemId(params);
    if (!itemIdResult.ok) {
      this.loadError = itemIdResult.getError().message;
      this.loading = false;
      return;
    }
    this.itemId = itemIdResult.getData();
    this.loadStateForCurrentRevision(true);
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
    Column() {
      Text('借出与归还')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), top: $r('app.float.space_4'), bottom: $r('app.float.space_3') })

      if (this.loading) {
        LoadingState({ text: '正在读取借还记录…' })
      } else if (!this.contentLoaded && this.loadError.length > 0) {
        ErrorState({ message: this.loadError })
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_4') }) {
            Text(`当前借出：${this.borrowedQuantity}`)
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .padding($r('app.float.space_4'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_card'))

            TextInput({ text: this.quantityText, placeholder: '数量' })
              .type(InputType.NUMBER_DECIMAL)
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.quantityText = value)
            TextInput({ text: this.counterpart, placeholder: '借给谁，可选' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.counterpart = value)
            TextInput({ text: this.note, placeholder: '备注，可选' })
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 1, color: $r('app.color.border_subtle') })
              .borderRadius($r('app.float.radius_control'))
              .onChange((value: string) => this.note = value)

            Row({ space: $r('app.float.space_2') }) {
              Button('借出')
                .layoutWeight(1)
                .fontColor($r('app.color.brand_on_primary'))
                .backgroundColor($r('app.color.brand_primary'))
                .borderRadius($r('app.float.radius_control'))
                .enabled(!this.submitting)
                .scale({ x: this.pressedAction === 'borrow' ? 0.98 : 1, y: this.pressedAction === 'borrow' ? 0.98 : 1 })
                .animation({ duration: 120, curve: Curve.EaseOut })
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.pressedAction = 'borrow';
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedAction = '';
                  }
                })
                .onClick(() => this.borrow())
              Button('归还')
                .layoutWeight(1)
                .fontColor($r('app.color.brand_primary'))
                .backgroundColor($r('app.color.surface_accent'))
                .borderRadius($r('app.float.radius_control'))
                .enabled(!this.submitting)
                .scale({ x: this.pressedAction === 'return' ? 0.98 : 1, y: this.pressedAction === 'return' ? 0.98 : 1 })
                .animation({ duration: 120, curve: Curve.EaseOut })
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.pressedAction = 'return';
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedAction = '';
                  }
                })
                .onClick(() => this.returnItem())
            }
            .width('100%')

            if (this.actionError.length > 0) {
              ErrorState({ message: this.actionError })
            } else if (this.loadError.length > 0) {
              ErrorState({ message: this.loadError })
            }

            Text('操作记录')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            ForEach(this.events, (event: TraceEvent) => {
              Column({ space: $r('app.float.space_1') }) {
                Text(`${this.eventLabel(event.type)} ${event.quantity}`)
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text(`${new Date(event.createdAt).toLocaleString()}${event.counterpart === undefined ? '' : ` · ${event.counterpart}`}`)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding($r('app.float.space_3'))
              .backgroundColor($r('app.color.surface_card'))
              .borderRadius($r('app.float.radius_control'))
            }, (event: TraceEvent) => event.id)
          }
          .width('100%')
          .padding({ left: $r('app.float.space_4'), right: $r('app.float.space_4'), bottom: $r('app.float.space_6') })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom })
    .backgroundColor($r('app.color.surface_app'))
  }

  private async loadState(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.loading = true;
      this.loadError = '';
    }
    try {
      const state = await AppServices.get().lending.getState(this.itemId);
      const events = await AppServices.get().lending.getEvents(this.itemId);
      if (!state.ok) {
        this.loadError = state.getError().message;
      } else if (!events.ok) {
        this.loadError = events.getError().message;
      } else {
        this.borrowedQuantity = state.getData().borrowedQuantity;
        this.events = events.getData();
        this.contentLoaded = true;
        this.loadError = '';
      }
    } catch (_) {
      this.loadError = '读取借还记录失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private async borrow(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().lending.borrow(this.itemId, Number(this.quantityText), this.counterpart, undefined, this.note);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadState(false);
      this.showToast('借出已记录');
    } catch (_) {
      this.actionError = '借出失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  private async returnItem(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.pressedAction = '';
    this.actionError = '';
    try {
      const result = await AppServices.get().lending.returnItem(this.itemId, Number(this.quantityText), undefined, this.note);
      if (!result.ok) {
        this.actionError = result.getError().message;
        return;
      }
      this.lastHandledDataRevision = AppEventBus.notifyDataChanged();
      await this.loadState(false);
      this.showToast('归还已记录');
    } catch (_) {
      this.actionError = '归还失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  private eventLabel(type: TraceEventType): string {
    if (type === TraceEventType.BORROW) {
      return '借出';
    }
    if (type === TraceEventType.RETURN) {
      return '归还';
    }
    return '记录';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1600
      });
    } catch (_) {
    }
  }
}
