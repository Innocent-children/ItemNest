import { failure, Result, success } from '../common/Result';
import { ReminderRepositoryPort } from '../data/repository/ReminderRepository';
import { HomeSummaryService } from './HomeSummaryService';
import { LendingService } from './LendingService';
import { FormSnapshot, FormEntry } from '../model/FormSnapshot';

export class FormSnapshotProvider {
  private homeSummary: HomeSummaryService;
  private reminders: ReminderRepositoryPort;
  private lending: LendingService;

  constructor(homeSummary: HomeSummaryService, reminders: ReminderRepositoryPort, lending: LendingService) {
    this.homeSummary = homeSummary; this.reminders = reminders; this.lending = lending;
  }

  async getSnapshot(now: Date = new Date()): Promise<Result<FormSnapshot>> {
    const summary = await this.homeSummary.getSummary(now);
    if (!summary.ok) { return failure(summary.getError()); }
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).getTime();
    const reminders = await this.reminders.countScheduledBetween(start, end);
    if (!reminders.ok) { return failure(reminders.getError()); }
    const loans = await this.lending.getOutstandingLoans();
    if (!loans.ok) { return failure(loans.getError()); }
    const expiryEntries: FormEntry[] = summary.getData().expiryAttentionItems.slice(0, 3).map((item): FormEntry => {
      const days = Math.round((new Date((item.expirationDate ?? '').replace(/-/g, '/') + ' 00:00:00').getTime() - start) / 86400000);
      return { itemId: item.id, title: item.name,
        subtitle: (days < 0 ? '已过期 ' + -days + ' 天' : days === 0 ? '今天到期' : days + ' 天后到期') +
          ' · ' + (item.activeLocationPaths?.join('、') || item.locationPath || '未记录位置') };
    });
    const loanEntries: FormEntry[] = loans.getData().slice(0, 3).map((loan): FormEntry => ({ itemId: loan.itemId, title: loan.itemName,
      subtitle: (loan.loan.borrowEvent.counterpart || '未记录借用人') + ' · 待还 ' + loan.loan.remainingQuantity + loan.unit +
        ' · ' + new Date(loan.loan.borrowEvent.createdAt).toLocaleDateString() }));
    return success<FormSnapshot>({ dueSoonCount: summary.getData().dueSoonCount.toString(), todayReminderCount: reminders.getData().toString(),
      expiryEntries: expiryEntries, loanEntries: loanEntries, loanCount: loans.getData().length.toString(),
      updatedLabel: (now.getMonth() + 1) + '/' + now.getDate() + ' ' + now.getHours().toString().padStart(2, '0') + ':' +
        now.getMinutes().toString().padStart(2, '0') + ' 更新', error: '' });
  }

  failedSnapshot(): FormSnapshot {
    return { dueSoonCount: '—', todayReminderCount: '—', expiryEntries: [], loanEntries: [], loanCount: '—',
      updatedLabel: '', error: '暂时无法更新，点击打开应用重试' };
  }
}
