import { Category } from './Category';

export class ItemQuery {
  name: string = '';
  locationPath?: string;
  category?: Category;

  constructor(name: string = '', locationPath?: string, category?: Category) {
    this.name = name;
    this.locationPath = locationPath;
    this.category = category;
  }

  normalized(): ItemQuery {
    const normalizedLocation = this.locationPath?.trim();
    return new ItemQuery(
      this.name.trim(),
      normalizedLocation === undefined || normalizedLocation.length === 0 ? undefined : normalizedLocation,
      this.category
    );
  }

  isEmpty(): boolean {
    const value = this.normalized();
    return value.name.length === 0 && value.locationPath === undefined && value.category === undefined;
  }

  clear(): void {
    this.name = '';
    this.locationPath = undefined;
    this.category = undefined;
  }
}
