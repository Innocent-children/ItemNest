import { AppIcon } from '../model/AppIcon';

/**
 * 系统启动图是静态资源，人物图标在应用进程读取系统当前选择后展示。
 */
@Component
export struct StartupBrand {
  @StorageLink('itemnest.launchIcon') private icon: string = '';

  build() {
    Stack() {
      if (this.icon === AppIcon.GIRL || this.icon === AppIcon.BUDDY) {
        Stack() {
          Image($r('app.media.background')).width('100%').height('100%')
          Image(this.icon === AppIcon.BUDDY ? $r('app.media.buddy_foreground') : $r('app.media.foreground'))
            .width('100%').height('100%').objectFit(ImageFit.Contain)
        }.width(128).height(128).borderRadius(28).clip(true)
          .accessibilityText($r('app.string.app_name'))
      }
    }.width('100%').height('100%')
      .backgroundColor($r('app.color.start_window_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
