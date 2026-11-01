export class CardLine {
  key: string = '';
  id: string = '';
  title: string = '';
  detail: string = '';
  urgent: boolean = false;
  sortDate: string = '';
}

export class CardContent {
  wide: boolean = false;
  mode: string = 'QUICK';
  summary: boolean = false;
  lines: CardLine[] = [];
  updated: string = '';
  constructor(wide: boolean = false, mode: string = 'QUICK') {
    this.wide = wide;
    this.mode = mode;
  }
}
