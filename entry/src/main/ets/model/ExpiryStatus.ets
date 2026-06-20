export enum ExpiryStatus {
  NO_EXPIRY_DATE = 'NO_EXPIRY_DATE',
  NORMAL = 'NORMAL',
  DUE_SOON = 'DUE_SOON',
  EXPIRED = 'EXPIRED'
}

export function expiryStatusLabel(status: ExpiryStatus): string {
  switch (status) {
    case ExpiryStatus.NORMAL:
      return '正常';
    case ExpiryStatus.DUE_SOON:
      return '即将到期';
    case ExpiryStatus.EXPIRED:
      return '已过期';
    case ExpiryStatus.NO_EXPIRY_DATE:
    default:
      return '无到期日期';
  }
}
