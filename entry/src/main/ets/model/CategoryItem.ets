export class CategoryItem {
  id: string = '';
  name: string = '';
  icon: string | null = null;
  active: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;
  constructor(init?: Partial<CategoryItem>) { Object.assign(this, init); }
}
