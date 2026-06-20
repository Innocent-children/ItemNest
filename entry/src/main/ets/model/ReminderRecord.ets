export enum ReminderRecordStatus {
  SCHEDULED = 'SCHEDULED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
  NOT_REQUIRED = 'NOT_REQUIRED'
}

export interface ReminderRecord {
  itemId: string;
  scheduledAt?: number;
  systemReminderId?: number;
  status: ReminderRecordStatus;
  errorSummary?: string;
  updatedAt: number;
}
