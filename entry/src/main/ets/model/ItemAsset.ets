export enum AssetSource {
  PHOTO_PICKER = 'PHOTO_PICKER',
  SYSTEM_CAMERA = 'SYSTEM_CAMERA'
}

export interface ItemAsset {
  id: string;
  itemId: string;
  localPath: string;
  source: AssetSource;
  createdAt: number;
}
