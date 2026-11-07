import { common } from '@kit.AbilityKit';
import { Repository } from '../data/Repository';
import { MediaService } from '../services/MediaService';

@Component
export struct PhotoViewer {
  repository: Repository = new Repository();
  @Prop @Watch('photosChanged') ids: string[] = [];
  initialId: string = '';
  onSelect: (id: string) => void = () => {};
  @State index: number = 0;
  @State zoom: number = 1;
  @StorageProp('reducedMotion') reducedMotion: boolean = false;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  private viewportWidth: number = 0;
  private currentPhoto: string = '';
  private panStartX: number = 0;
  private panStartY: number = 0;
  private startZoom: number = 1;
  private startX: number = 0;
  private startY: number = 0;
  private centerX: number = 0;
  private centerY: number = 0;
  private readonly viewportHeight: number = 400;

  aboutToAppear(): void {
    this.currentPhoto = this.initialId;
    this.photosChanged();
  }
  private photosChanged(): void {
    this.index = Math.max(0, this.ids.indexOf(this.currentPhoto));
    this.currentPhoto = this.ids[this.index] ?? '';
  }
  private move(x: number, y: number): void {
    const asset = this.repository.data.assets.find(value => value.id === this.ids[this.index]);
    if (!asset || !asset.width || !asset.height || !this.viewportWidth) return;
    const fit = Math.min(this.viewportWidth / asset.width, this.viewportHeight / asset.height) * this.zoom;
    const limitX = Math.max(0, (asset.width * fit - this.viewportWidth) / 2);
    const limitY = Math.max(0, (asset.height * fit - this.viewportHeight) / 2);
    this.offsetX = Math.max(-limitX, Math.min(limitX, x));
    this.offsetY = Math.max(-limitY, Math.min(limitY, y));
  }
  private reset(scale: number = 1): void {
    this.zoom = scale;
    this.offsetX = 0;
    this.offsetY = 0;
  }
  private zoomTo(scale: number): void {
    this.getUIContext().animateTo({ duration: this.reducedMotion ? 0 : 180, curve: Curve.EaseOut }, () => this.reset(scale));
  }
  build() {
    Column({ space: 12 }) {
      Swiper() {
        ForEach(this.ids, (id: string) => {
          Stack() {
            Image(new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository).uri(id))
              .width('100%').height('100%').objectFit(ImageFit.Contain)
              .scale({ x: this.ids[this.index] === id ? this.zoom : 1, y: this.ids[this.index] === id ? this.zoom : 1 })
              .translate({ x: this.ids[this.index] === id ? this.offsetX : 0, y: this.ids[this.index] === id ? this.offsetY : 0 })
          }.width('100%').height(this.viewportHeight).clip(true)
            .accessibilityText(`第 ${this.ids.indexOf(id) + 1} 张照片，双击或双指缩放`)
            .gesture(GestureGroup(GestureMode.Exclusive,
              PinchGesture()
                .onActionStart((event: GestureEvent) => {
                  this.startZoom = this.zoom;
                  this.startX = this.offsetX; this.startY = this.offsetY;
                  this.centerX = event.pinchCenterX - this.viewportWidth / 2;
                  this.centerY = event.pinchCenterY - this.viewportHeight / 2;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.zoom = Math.max(1, Math.min(4, this.startZoom * event.scale));
                  const ratio = this.zoom / this.startZoom;
                  this.move(event.pinchCenterX - this.viewportWidth / 2 - (this.centerX - this.startX) * ratio,
                    event.pinchCenterY - this.viewportHeight / 2 - (this.centerY - this.startY) * ratio);
                })
                .onActionCancel(() => { this.zoom = this.startZoom; this.move(this.startX, this.startY); }),
              TapGesture({ count: 2 }).onAction(() => this.zoomTo(this.zoom > 1 ? 1 : 2))))
            .parallelGesture(PanGesture({ fingers: 1 }).tag('panZoomedPhoto')
              .onActionStart(() => { this.panStartX = this.offsetX; this.panStartY = this.offsetY; })
              .onActionUpdate((event: GestureEvent) => {
                if (this.zoom > 1) this.move(this.panStartX + event.offsetX, this.panStartY + event.offsetY);
              }))
            .onGestureJudgeBegin((info: GestureInfo) =>
              info.tag === 'panZoomedPhoto' && this.zoom <= 1 ? GestureJudgeResult.REJECT : GestureJudgeResult.CONTINUE)
        }, (id: string) => id)
      }.width('100%').height(this.viewportHeight).index(this.index).loop(false).indicator(false).disableSwipe(this.zoom > 1)
        .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); this.move(this.offsetX, this.offsetY); })
        .onChange((index: number) => { this.index = index; this.currentPhoto = this.ids[index]; this.reset(); this.onSelect(this.currentPhoto); })
      Text(`第 ${this.index + 1} / ${this.ids.length} 张 · ${this.zoom > 1 ? `已放大 ${Math.round(this.zoom * 100)}%，单指移动` : '双击放大，双指缩放'}`).fontSize(13).fontColor($r('app.color.secondary'))
      if (this.zoom > 1) { Button('恢复全图').onClick(() => this.zoomTo(1)) }
    }.width('100%')
  }
}
