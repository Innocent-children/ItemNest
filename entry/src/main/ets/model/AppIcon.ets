export enum AppIcon {
  GIRL = 'moving_girl',
  BUDDY = 'moving_buddy'
}

export interface AppIconState {
  supported: boolean;
  current: AppIcon;
}
