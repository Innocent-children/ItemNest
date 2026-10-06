export interface FormEntry {
  itemId: string;
  title: string;
  subtitle: string;
}

export interface FormSnapshot {
  dueSoonCount: string;
  todayReminderCount: string;
  loanCount: string;
  expiryEntries: FormEntry[];
  loanEntries: FormEntry[];
  updatedLabel: string;
  error: string;
}
