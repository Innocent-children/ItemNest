import { failure, Result, success } from '../common/Result';
import { ReminderRepositoryPort } from '../data/repository/ReminderRepository';
import { HomeSummaryService } from './HomeSummaryService';

export class FormSnapshot {
  readonly dueSoonCount: number;
  readonly todayReminderCount: number;

  constructor(dueSoonCount: number, todayReminderCount: number) {
    this.dueSoonCount = dueSoonCount;
    this.todayReminderCount = todayReminderCount;
  }
}

export class FormSnapshotProvider {
  private readonly homeSummary: HomeSummaryService;
  private readonly reminders: ReminderRepositoryPort;

  constructor(homeSummary: HomeSummaryService, reminders: ReminderRepositoryPort) {
    this.homeSummary = homeSummary;
    this.reminders = reminders;
  }

  async getSnapshot(now: Date = new Date()): Promise<Result<FormSnapshot>> {
    const summaryResult = await this.homeSummary.getSummary(now);
    if (!summaryResult.ok) {
      return failure<FormSnapshot>(summaryResult.getError());
    }
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).getTime();
    const reminderCountResult = await this.reminders.countScheduledBetween(startOfDay, endOfDay);
    if (!reminderCountResult.ok) {
      return failure<FormSnapshot>(reminderCountResult.getError());
    }
    return success<FormSnapshot>(new FormSnapshot(summaryResult.getData().dueSoonCount, reminderCountResult.getData()));
  }
}
