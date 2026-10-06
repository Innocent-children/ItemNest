import { CaptureDraft } from '../model/SystemFeatures';

/**
 * OCR只提供候选值。没有明确日期标签时保留候选，不把生产日期当作到期日。
 */
export class CaptureDraftService {
  parse(text: string): CaptureDraft {
    const lines = text.split(/[\n\r]+/).map((line: string) => line.trim()).filter((line: string) => line.length > 0);
    const dates: string[] = [];
    const pattern = /(?:20\d{2})\s*[年.\/-]\s*\d{1,2}\s*[月.\/-]\s*\d{1,2}\s*日?/g;
    let match = pattern.exec(text);
    while (match !== null) {
      const date = this.normalizeDate(match[0]);
      if (date.length > 0 && dates.indexOf(date) < 0) { dates.push(date); }
      match = pattern.exec(text);
    }
    const production = this.labeledDate(lines, /生产日期|制造日期|生产时间/);
    const expiration = this.labeledDate(lines, /到期日|有效期至|有效日期至|保质期至|限用日期|失效日期|最佳食用期至/);
    const shelf = text.match(/保质期\s*[:：]?\s*(\d+)\s*(天|日|个月|月|年)/);
    const nameLine = lines.find((line: string) => /^(?:产品名称|商品名称|品名|名称)\s*[:：]/.test(line));
    return {
      name: nameLine === undefined ? '' : nameLine.replace(/^(?:产品名称|商品名称|品名|名称)\s*[:：]\s*/, '').slice(0, 80),
      productionDate: production,
      expirationDate: expiration,
      shelfLife: shelf === null ? '' : shelf[1] + shelf[2],
      text: text,
      dateCandidates: dates,
      notice: expiration.length > 0 ? '请对照原图确认名称和到期日期后保存。' :
        '尚未确认到期日期，请对照包装选择或填写；生产日期不会自动作为到期日期。'
    };
  }

  normalizeDate(input: string): string {
    const match = input.match(/^(20\d{2})\s*[年.\/-]\s*(\d{1,2})\s*[月.\/-]\s*(\d{1,2})\s*日?$/);
    if (match === null) { return ''; }
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const date = new Date(year, month - 1, day);
    return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day ?
      year.toString() + '-' + month.toString().padStart(2, '0') + '-' + day.toString().padStart(2, '0') : '';
  }

  private labeledDate(lines: string[], label: RegExp): string {
    for (let index = 0; index < lines.length; index++) {
      if (!label.test(lines[index])) { continue; }
      const labelMatch = label.exec(lines[index]);
      const line = labelMatch === null ? '' : lines[index].substring(labelMatch.index + labelMatch[0].length);
      const match = line.match(/20\d{2}\s*[年.\/-]\s*\d{1,2}\s*[月.\/-]\s*\d{1,2}\s*日?/);
      if (match !== null) { return this.normalizeDate(match[0]); }
      if (index + 1 < lines.length) {
        const next = this.normalizeDate(lines[index + 1]);
        if (next.length > 0) { return next; }
      }
    }
    return '';
  }
}
