import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Repository } from '../data/Repository';
import { Item, ItemDate, displayName, copy, reminderClock } from '../model/Models';

export class ReminderResult {
  day: string = '';
  count: number = 0;
  state: string = 'PENDING';
  message: string = '';
  eventId: number = -1;
  versions: string[] = [];
  scheduledAt: number = 0;
}
class PlannedDay {
  day: string = '';
  names: string[] = [];
  versions: string[] = [];
}
class CalendarDeviceState {
  reached: string[] = [];
  results: ReminderResult[] = [];
  pendingCleanup:boolean=false;
}
export class CalendarService {
  private context: common.UIAbilityContext;
  private repository: Repository;
  private running: boolean = false;
  private again: boolean = false;
  results: ReminderResult[] = [];
  onChange: () => void = () => {};
  constructor(context: common.UIAbilityContext, repository: Repository) { this.context = context; this.repository = repository; }
  async enable(): Promise<void> {
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR']);
    if (result.authResults.some((value: number) => value !== 0)) throw new Error('日期已保存。允许日历访问后可以开启到期提醒。');
    const pref = copy(this.repository.data.preference); pref.reminderEnabled = true; this.repository.savePreference(pref);
    await this.sync();
  }
  private load(): CalendarDeviceState {
    const path = this.context.filesDir + '/calendar-device.json';
    if (!fs.accessSync(path)) return new CalendarDeviceState();
    return JSON.parse(fs.readTextSync(path)) as CalendarDeviceState;
  }
  private save(state: CalendarDeviceState): void {
    const path = this.context.filesDir + '/calendar-device.json'; const file = fs.openSync(path + '.tmp', fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, JSON.stringify(state)); fs.fsyncSync(file.fd); } finally { fs.closeSync(file); }
    fs.renameSync(path + '.tmp', path);
  }
  async sync(): Promise<void> {
    if (this.running) { this.again = true; return; } this.running = true;
    try { do { this.again = false; await this.reconcile(); } while (this.again); }
    catch(_){const result=new ReminderResult();result.message='日期已保存，系统提醒状态待核对';this.results=[result];this.onChange();}
    finally { this.running = false; }
  }
  private async reconcile(): Promise<void> {
    const snapshot = copy(this.repository.data); const device = this.load(); const plans: PlannedDay[] = [];
    device.results.filter((result: ReminderResult) => result.state === 'REGISTERED' && result.scheduledAt > 0 && result.scheduledAt <= Date.now()).forEach((result: ReminderResult) => { (result.versions ?? []).forEach((version: string) => { if (!device.reached.includes(version)) device.reached.push(version); }); });
    snapshot.items.filter((item: Item) => !item.deletedAt && item.status !== 'ARCHIVED').forEach((item: Item) => item.dates.filter((date: ItemDate) => !date.handledAt && date.remindEnabled).forEach((date: ItemDate) => {
      const version = date.id + ':' + date.dateVersion;
      if (device.reached.includes(version)) return;
      if (new Date(date.date + 'T09:00:00').getTime() <= Date.now()) { device.reached.push(version); return; }
      let plan = plans.find((entry: PlannedDay) => entry.day === date.date);
      if (!plan) { plan = new PlannedDay(); plan.day = date.date; plans.push(plan); }
      plan.names.push(displayName(item)); plan.versions.push(version);
    }));
    const results: ReminderResult[] = plans.sort((a: PlannedDay, b: PlannedDay) => a.day.localeCompare(b.day)).map((plan: PlannedDay) => { const result = new ReminderResult(); result.day = plan.day; result.count = plan.names.length; result.state = snapshot.preference.reminderEnabled ? 'PENDING' : 'LOCAL_ONLY'; result.message = snapshot.preference.reminderEnabled ? '等待安排' : '日期已保存'; return result; });
    try {
      const manager = calendarManager.getCalendarManager(this.context);
      const calendars = await manager.getAllCalendars();
      let calendar = calendars.find((entry: calendarManager.Calendar) => entry.getAccount().name === 'com.imotong.itemnest');
      if (!calendar && snapshot.preference.reminderEnabled) calendar = await manager.createCalendar({ name: 'com.imotong.itemnest', type: calendarManager.CalendarType.LOCAL, displayName: '我的家当' });
      if (calendar) {
        await calendar.setConfig({ enableReminder: true, color: '#23624A' });
        const events = await calendar.getEvents();
        const future = events.filter((event: calendarManager.Event) => event.startTime > Date.now() && event.identifier?.startsWith('itemnest:'));
        for (const event of future) {
          const day = event.identifier?.slice(9) ?? '';
          if (!snapshot.preference.reminderEnabled || !plans.some((plan: PlannedDay) => plan.day === day)) { if (event.id !== undefined) await calendar.deleteEvent(event.id); }
        }
        device.pendingCleanup=false;
        if (snapshot.preference.reminderEnabled) {
          for (const plan of plans) {
            const result = results.find((entry: ReminderResult) => entry.day === plan.day)!;
            const duplicates = future.filter((event: calendarManager.Event) => event.identifier === 'itemnest:' + plan.day);
            for (const duplicate of duplicates.slice(1)) { if (duplicate.id !== undefined) await calendar.deleteEvent(duplicate.id); }
            const old = duplicates[0]; const start = new Date(plan.day + 'T09:00:00').getTime();
            const event: calendarManager.Event = { type: calendarManager.EventType.NORMAL, title: `我的家当 · ${plan.names.length} 条日期提醒`, startTime: start, endTime: start + 300000, reminderTime: [0], identifier: 'itemnest:' + plan.day, description: snapshot.preference.externalDetails ? plan.names.slice(0, 3).join('、') + (plan.names.length > 3 ? `等 ${plan.names.length} 条` : '') + ` · ${plan.day}，打开我的家当查看日期与处理` : '打开我的家当查看日期与处理' };
            try {
              if (old?.id !== undefined) { event.id = old.id; if (old.title !== event.title || old.description !== event.description || old.startTime !== event.startTime) await calendar.updateEvent(event); result.eventId = old.id; }
              else result.eventId = await calendar.addEvent(event);
              if (result.eventId < 0) throw new Error('日历尚未完成登记');
              result.state = 'REGISTERED'; result.message = `当天 ${reminderClock()} 提醒已写入系统日历`;
              result.versions = plan.versions; result.scheduledAt = start;
            } catch (error) { result.state = 'PENDING'; result.message = '日期已保存，日历待安排：' + (error as Error).message; }
          }
        }
      }
    } catch (error) {
      results.forEach((result: ReminderResult) => { result.message = snapshot.preference.reminderEnabled ? '日历访问待开启，日期仍可在应用内关注' : '日期已保存'; });
      if (device.pendingCleanup || device.results.some((result: ReminderResult) => result.state === 'REGISTERED' && new Date(result.day + 'T09:00:00').getTime() > Date.now())) {
        device.pendingCleanup=true;
        const pending = new ReminderResult(); pending.state = 'CANCEL_PENDING'; pending.message = '未来日程待清理，请重新允许日历访问或在系统日历中删除“我的家当”的未来日程'; results.unshift(pending);
      }
    }
    device.results = results; this.save(device); this.results = results; this.onChange();
  }
}
