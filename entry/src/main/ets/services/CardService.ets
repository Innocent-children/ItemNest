import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { Repository } from '../data/Repository';
import { Item, ItemDate, displayName, daysUntil, relativeDue } from '../model/Models';
import { CardContent, CardLine } from '../cards/CardContent';

export class CardService {
  static initial(dimension: number, name: string): CardContent {
    const data = new CardContent();
    data.wide = dimension === 3;
    data.mode = name.startsWith('NestDates') ? 'DATES' : data.wide ? 'COMMON' : 'QUICK';
    return data;
  }

  static content(repository: Repository, dimension: number, name: string): CardContent {
    const data = CardService.initial(dimension, name);
    data.summary = repository.data.preference.cardSummary;
    if (data.mode === 'QUICK' || !data.summary) return data;
    const items = repository.data.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED');
    if (data.mode === 'DATES') {
      items.forEach((item: Item) => item.dates.filter((date: ItemDate) => !date.handledAt).forEach((date: ItemDate) => {
        const line = new CardLine();
        line.key = item.id + ':' + date.id;
        line.id = item.id;
        line.title = displayName(item);
        line.detail = relativeDue(date.date, date.type);
        line.sortDate = date.date;
        line.urgent = daysUntil(date.date) <= 0;
        data.lines.push(line);
      }));
      data.lines.sort((a: CardLine, b: CardLine) => a.sortDate.localeCompare(b.sortDate) || a.key.localeCompare(b.key));
    } else {
      repository.data.preference.cardIds.forEach((id: string) => {
        const item = items.find((value: Item) => value.id === id);
        if (!item) return;
        const line = new CardLine();
        line.key = item.id;
        line.id = item.id;
        line.title = displayName(item);
        line.detail = item.status === 'LENT' ? '借给 ' + (item.borrower || '他人') : repository.path(item.locationId) || '位置待补充';
        data.lines.push(line);
      });
    }
    data.lines = data.lines.slice(0, data.wide ? 3 : 1);
    const now = new Date();
    data.updated = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    return data;
  }

  static async refresh(repository: Repository): Promise<void> {
    const forms = await formProvider.getPublishedRunningFormInfos();
    await Promise.all(forms.map(async (form) => {
      try {
        await formProvider.updateForm(form.formId, formBindingData.createFormBindingData(CardService.content(repository, form.dimension, form.formName)));
      } catch (_) {}
    }));
  }

  static async update(context: common.Context, id: string, dimension: number = 0, name: string = ''): Promise<void> {
    const repository = new Repository();
    await repository.open(context);
    try {
      if (!dimension || !name) {
        const info = await formProvider.getPublishedRunningFormInfoById(id);
        dimension = info.dimension;
        name = info.formName;
      }
      await formProvider.updateForm(id, formBindingData.createFormBindingData(CardService.content(repository, dimension, name)));
    } finally {
      repository.close();
    }
  }
}
