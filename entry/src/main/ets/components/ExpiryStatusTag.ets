import { expiryStatusLabel, ExpiryStatus } from '../model/ExpiryStatus';

@Component
export struct ExpiryStatusTag {
  @Prop status: ExpiryStatus = ExpiryStatus.NO_EXPIRY_DATE;

  build() {
    Text(expiryStatusLabel(this.status))
      .fontSize(12)
      .fontColor(this.textColor())
      .backgroundColor(this.tagBackgroundColor())
      .borderRadius(12)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  private textColor(): string {
    switch (this.status) {
      case ExpiryStatus.EXPIRED:
        return '#B42318';
      case ExpiryStatus.DUE_SOON:
        return '#B54708';
      case ExpiryStatus.NORMAL:
        return '#027A48';
      case ExpiryStatus.NO_EXPIRY_DATE:
      default:
        return '#475467';
    }
  }

  private tagBackgroundColor(): string {
    switch (this.status) {
      case ExpiryStatus.EXPIRED:
        return '#FEE4E2';
      case ExpiryStatus.DUE_SOON:
        return '#FEF0C7';
      case ExpiryStatus.NORMAL:
        return '#D1FADF';
      case ExpiryStatus.NO_EXPIRY_DATE:
      default:
        return '#EAECF0';
    }
  }
}
