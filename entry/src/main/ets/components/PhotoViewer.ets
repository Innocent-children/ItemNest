import { localImageSource } from '../ui/ImageSource';
import { uiSpring } from '../ui/VisualStyle';
import { NavigationHelper } from '../navigation/NavigationHelper';

/**
 * 缩略图与查看层共用图片，缩放和位移仅影响查看层。
 */
@Component
export struct PhotoViewer {
  @Prop path: string = '';
  @Prop transitionId: string = '';
  @Link visible: boolean;
  @StorageLink('itemtrace.reduceAnimation') private reduceAnimation: boolean = false;
  @State private scaleValue: number = 1;
  @State private offsetX: number = 0;
  @State private offsetY: number = 0;
  private startScale: number = 1;
  private startX: number = 0;
  private startY: number = 0;
  private backHandler: () => boolean = () => { this.close(); return true; };

  aboutToAppear(): void {
    NavigationHelper.registerBackHandler(this.backHandler);
  }

  aboutToDisappear(): void {
    NavigationHelper.unregisterBackHandler(this.backHandler);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(localImageSource(this.path)).width('100%').height('100%').objectFit(ImageFit.Contain)
        .geometryTransition(this.reduceAnimation ? '' : this.transitionId)
        .scale({ x: this.scaleValue, y: this.scaleValue })
        .translate({ x: this.offsetX, y: this.offsetY })
        .gesture(GestureGroup(GestureMode.Parallel,
          PinchGesture()
            .onActionStart(() => this.startScale = this.scaleValue)
            .onActionUpdate((event: GestureEvent) => { this.scaleValue = Math.max(1, Math.min(5, this.startScale * event.scale)); })
            .onActionEnd(() => {
              if (this.scaleValue === 1) {
                this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => {
                  this.offsetX = 0; this.offsetY = 0;
                });
              }
            }),
          PanGesture()
            .onActionStart(() => { this.startX = this.offsetX; this.startY = this.offsetY; })
            .onActionUpdate((event: GestureEvent) => {
              if (this.scaleValue > 1) { this.offsetX = this.startX + event.offsetX; this.offsetY = this.startY + event.offsetY; }
            })
            .onActionEnd((event: GestureEvent) => {
              if (this.scaleValue === 1 && event.offsetY > 100) { this.close(); }
            }),
          TapGesture({ count: 2 }).onAction(() => this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => {
            this.scaleValue = this.scaleValue > 1 ? 1 : 2.5;
            this.offsetX = 0;
            this.offsetY = 0;
          }))
        ))
      Button('关闭照片').height(44).margin(16).fontColor(Color.White)
        .backgroundColor('#CC000000').borderRadius(22).zIndex(1)
        .onClick(() => this.close())
    }.width('100%').height('100%').backgroundColor('#F2000000')
      .clip(true).zIndex(20).transition(TransitionEffect.OPACITY.animation(uiSpring(this.reduceAnimation)))
      .accessibilityText('照片查看，双指缩放，双击恢复或放大')
  }

  private close(): void {
    this.getUIContext().animateTo(uiSpring(this.reduceAnimation), () => this.visible = false);
  }
}
