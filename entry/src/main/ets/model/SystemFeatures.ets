export interface SystemFeatures {
  assistantEnabled: boolean;
  searchEnabled: boolean;
  searchLocationVisible: boolean;
  photoSearchEnabled: boolean;
  liveViewEnabled: boolean;
}

export interface CaptureDraft {
  name: string;
  productionDate: string;
  expirationDate: string;
  shelfLife: string;
  text: string;
  dateCandidates: string[];
  notice: string;
}

export interface ExternalRequest {
  action: string;
  itemId?: string;
  locationId?: string;
  name?: string;
  quantity?: number;
  unit?: string;
  locationPath?: string;
  expirationDate?: string;
  counterpart?: string;
  borrowEventId?: string;
  batchId?: string;
  photoUri?: string;
  text?: string;
}
