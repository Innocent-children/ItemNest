import { common } from '@kit.AbilityKit';
import { Repository } from '../data/Repository';
import { MediaService } from '../services/MediaService';

@Component
export struct PhotoViewer {
  repository: Repository = new Repository();
  @Prop ids: string[] = [];
  initialId: string = '';
  onSelect: (id: string) => void = () => {};
  @State index: number = 0;
  @State zoom: number = 1;
  aboutToAppear(): void { this.index = Math.max(0, this.ids.indexOf(this.initialId)); }
  build() {
    Column({ space: 12 }) {
      Swiper() {
        ForEach(this.ids, (id: string) => {
          Image(new MediaService(this.getUIContext().getHostContext() as common.UIAbilityContext, this.repository).uri(id))
            .width('100%').height(400).objectFit(ImageFit.Contain).scale({ x: this.zoom, y: this.zoom })
            .accessibilityText(`第 ${this.ids.indexOf(id) + 1} 张照片，双击或双指缩放`)
            .gesture(GestureGroup(GestureMode.Exclusive,
              PinchGesture().onActionUpdate((event: GestureEvent) => this.zoom = Math.min(4, Math.max(1, event.scale))),
              TapGesture({ count: 2 }).onAction(() => this.zoom = this.zoom > 1 ? 1 : 2)))
        }, (id: string) => id)
      }.width('100%').height(400).index(this.index).loop(false).indicator(false).disableSwipe(this.zoom > 1)
        .onChange((index: number) => { this.index = index; this.zoom = 1; this.onSelect(this.ids[index]); })
      Text(`第 ${this.index + 1} / ${this.ids.length} 张 · 双击放大，双指缩放`).fontSize(13).fontColor($r('app.color.secondary'))
      if (this.zoom > 1) { Button('恢复全图').onClick(() => this.zoom = 1) }
    }.width('100%')
  }
}
