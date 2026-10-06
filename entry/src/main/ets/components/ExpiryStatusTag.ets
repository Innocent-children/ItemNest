import { ExpiryStatus } from '../model/ExpiryStatus';
import { expiryDescription } from '../service/ItemFlowPresentation';

@Component
export struct ExpiryStatusTag {
  @Prop status: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;
  @Prop expirationDate: string = '';

  build() {
    Text(expiryDescription(this.status, this.expirationDate))
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .backgroundColor(this.tagBackgroundColor())
      .borderRadius(20)
      .padding({ left: $r('app.float.space_2'), right: $r('app.float.space_2'), top: $r('app.float.space_1'), bottom: $r('app.float.space_1') })
  }

  private textColor(): ResourceColor {
    switch (this.status) {
      case ExpiryStatus.EXPIRED:
        return $r('app.color.status_danger');
      case ExpiryStatus.DUE_SOON:
        return $r('app.color.status_warning');
      case ExpiryStatus.NORMAL:
        return $r('app.color.status_success');
      case ExpiryStatus.NO_EXPIRY_DATE:
      default:
        return $r('app.color.status_neutral');
    }
  }

  private tagBackgroundColor(): ResourceColor {
    switch (this.status) {
      case ExpiryStatus.EXPIRED:
        return $r('app.color.status_danger_soft');
      case ExpiryStatus.DUE_SOON:
        return $r('app.color.status_warning_soft');
      case ExpiryStatus.NORMAL:
        return $r('app.color.status_success_soft');
      case ExpiryStatus.NO_EXPIRY_DATE:
      default:
        return $r('app.color.status_neutral_soft');
    }
  }
}
