export class Location {
  id: string = '';
  parentId: string | null = null;
  name: string = '';
  path: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  constructor(init?: Partial<Location>) { Object.assign(this, init); }
}
