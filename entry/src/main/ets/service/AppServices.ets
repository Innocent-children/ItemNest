import { Context } from '@kit.AbilityKit';
import { ItemValidator } from '../common/ItemValidator';
import { ItemDao } from '../data/dao/ItemDao';
import { ItemRepository } from '../data/repository/ItemRepository';
import { RdbDatabase } from '../data/rdb/RdbDatabase';
import { AppError, AppErrorCode } from '../common/AppError';
import { ExpiryService } from './ExpiryService';
import { HomeSummaryService } from './HomeSummaryService';
import { ItemCreateService } from './ItemCreateService';
import { ItemDeleteService } from './ItemDeleteService';
import { ItemDetailService } from './ItemDetailService';
import { ItemListService } from './ItemListService';
import { ItemSearchService } from './ItemSearchService';
import { ItemUpdateService } from './ItemUpdateService';
import { PreferenceRepository } from '../data/repository/PreferenceRepository';
import { PreferenceService } from './PreferenceService';
import { ReminderDao } from '../data/dao/ReminderDao';
import { ReminderRepository } from '../data/repository/ReminderRepository';
import { ReminderService } from './ReminderService';
import { SystemReminderAdapter } from './adapter/ReminderAdapter';
import { AssetDao } from '../data/dao/AssetDao';
import { AssetRepository } from '../data/repository/AssetRepository';
import { LocalAssetStorage } from './LocalAssetStorage';
import { PhotoService } from './PhotoService';
import { SystemImageSourceAdapter } from './adapter/ImageSourceAdapter';
import { FormSnapshotProvider } from './FormSnapshotProvider';
import { ScanService } from './ScanService';
import { UnavailableScanAdapter } from './adapter/ScanAdapter';

export class AppServices {
  private static instance?: AppServices;

  readonly database: RdbDatabase;
  readonly repository: ItemRepository;
  readonly createItem: ItemCreateService;
  readonly listItems: ItemListService;
  readonly detailItem: ItemDetailService;
  readonly updateItem: ItemUpdateService;
  readonly deleteItem: ItemDeleteService;
  readonly searchItems: ItemSearchService;
  readonly homeSummary: HomeSummaryService;
  readonly preferences: PreferenceService;
  readonly reminders: ReminderService;
  readonly photos: PhotoService;
  readonly imageSource: SystemImageSourceAdapter;
  readonly formSnapshot: FormSnapshotProvider;
  readonly scan: ScanService;

  private constructor(context: Context) {
    const database = new RdbDatabase(context);
    const repository = new ItemRepository(new ItemDao(database));
    const validator = new ItemValidator();
    const expiryService = new ExpiryService();
    const listItems = new ItemListService(repository, expiryService);

    this.database = database;
    this.repository = repository;
    this.createItem = new ItemCreateService(repository, validator);
    this.listItems = listItems;
    this.detailItem = new ItemDetailService(repository);
    this.updateItem = new ItemUpdateService(repository, validator);
    const preferenceService = new PreferenceService(new PreferenceRepository(context));
    const reminderRepository = new ReminderRepository(new ReminderDao(database));
    const reminderService = new ReminderService(reminderRepository, preferenceService, new SystemReminderAdapter(), repository);
    const photoService = new PhotoService(new AssetRepository(new AssetDao(database)), repository, new LocalAssetStorage(context));
    this.deleteItem = new ItemDeleteService(repository, reminderService, photoService);
    this.searchItems = new ItemSearchService(repository, listItems);
    this.homeSummary = new HomeSummaryService(repository, expiryService);
    this.preferences = preferenceService;
    this.reminders = reminderService;
    this.photos = photoService;
    this.imageSource = new SystemImageSourceAdapter();
    this.formSnapshot = new FormSnapshotProvider(this.homeSummary, reminderRepository);
    this.scan = new ScanService(new UnavailableScanAdapter());
  }

  static configure(context: Context): void {
    if (AppServices.instance === undefined) {
      AppServices.instance = new AppServices(context);
    }
  }

  static get(): AppServices {
    if (AppServices.instance === undefined) {
      throw new AppError(AppErrorCode.DATABASE_INIT, '应用服务尚未初始化');
    }
    return AppServices.instance;
  }
}
