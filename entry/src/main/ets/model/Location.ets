export interface LocationRecord {
  id: string;
  name: string;
  parentId?: string;
  path: string;
  active: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface LocationDraft {
  name?: string;
  parentId?: string;
}

export interface LocationRenamePlan {
  oldPath: string;
  newPath: string;
  locations: LocationRecord[];
  updatedAt: number;
}

export function createLocationId(clock: () => number = () => Date.now()): string {
  return `location-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
