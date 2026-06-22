export enum Category {
  MEDICINE = '药品',
  FOOD = '食品',
  DOCUMENT = '证件',
  TOOL = '工具',
  OFFICE = '办公',
  DAILY_NECESSITIES = '生活用品',
  CHILDREN = '儿童用品',
  PET = '宠物用品',
  OTHER = '其他'
}

export const CATEGORY_OPTIONS: string[] = [
  Category.MEDICINE,
  Category.FOOD,
  Category.DOCUMENT,
  Category.TOOL,
  Category.OFFICE,
  Category.DAILY_NECESSITIES,
  Category.CHILDREN,
  Category.PET,
  Category.OTHER
];

export function isCategory(value: string): boolean {
  return CATEGORY_OPTIONS.indexOf(value) >= 0;
}

export interface CategoryRecord {
  id: string;
  name: string;
  active: boolean;
  systemPreset: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface CategoryDraft {
  name?: string;
}

export function createCategoryId(clock: () => number = () => Date.now()): string {
  return `category-${clock()}-${Math.floor(Math.random() * 1000000)}`;
}
