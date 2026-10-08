import { LocationLabelRepository } from '../data/repository/LocationLabelRepository';
import { LabelImageService } from './LabelImageService';
import { BackupProgressService } from './BackupProgressService';
import { SystemFeatureService } from './SystemFeatureService';
import { CaptureDraftService } from './CaptureDraftService';
import { TextRecognitionAdapter } from './adapter/TextRecognitionAdapter';
import { PhotoSearchService } from './PhotoSearchService';
import { LocationLabelService } from './LocationLabelService';
import { ShareService } from './ShareService';
import { Context } from '@kit.AbilityKit';
import { ItemValidator } from '../common/ItemValidator';
import { ItemDao } from '../data/dao/ItemDao';
import { BatchDao } from '../data/dao/BatchDao';
import { ItemRepository } from '../data/repository/ItemRepository';
import { BatchRepository } from '../data/repository/BatchRepository';
import { CategoryRepository } from '../data/repository/CategoryRepository';
import { LocationRepository } from '../data/repository/LocationRepository';
import { SearchHistoryRepository } from '../data/repository/SearchHistoryRepository';
import { StockThresholdRepository } from '../data/repository/StockThresholdRepository';
import { TraceEventRepository } from '../data/repository/TraceEventRepository';
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
import { SystemScanAdapter } from './adapter/ScanAdapter';
import { BatchService } from './BatchService';
import { BackupService } from './BackupService';
import { CategoryService } from './CategoryService';
import { ExportService } from './ExportService';
import { ImportService } from './ImportService';
import { LendingService } from './LendingService';
import { LocationService } from './LocationService';
import { LowStockReminderService } from './LowStockReminderService';
import { LowStockService } from './LowStockService';
import { RestoreService } from './RestoreService';
import { SearchSuggestionService } from './SearchSuggestionService';
import { PortableBackupService } from './PortableBackupService';
import { PortableFileStore } from './PortableFileStore';
import { PhotoMaintenanceService } from './PhotoMaintenanceService';
import { AppIconService } from './AppIconService';
import { SystemAppIconAdapter } from './adapter/AppIconAdapter';

export class AppServices {
  private static instance?: AppServices;

  readonly backupProgress: BackupProgressService;
  readonly systemFeatures: SystemFeatureService;
  readonly captureDraft: CaptureDraftService = new CaptureDraftService();
  readonly textRecognition: TextRecognitionAdapter = new TextRecognitionAdapter();
  readonly photoSearch: PhotoSearchService;
  readonly locationLabels: LocationLabelService;
  readonly labelImages: LabelImageService = new LabelImageService();
  readonly sharing: ShareService = new ShareService();
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
  readonly appIcon: AppIconService;
  readonly reminders: ReminderService;
  readonly photos: PhotoService;
  readonly photoMaintenance: PhotoMaintenanceService;
  readonly imageSource: SystemImageSourceAdapter;
  readonly formSnapshot: FormSnapshotProvider;
  readonly scan: ScanService;
  readonly batches: BatchService;
  readonly lowStock: LowStockService;
  readonly lowStockReminder: LowStockReminderService;
  readonly lending: LendingService;
  readonly locations: LocationService;
  readonly categories: CategoryService;
  readonly exportData: ExportService;
  readonly importData: ImportService;
  readonly backup: BackupService;
  readonly portableBackup: PortableBackupService;
  readonly restore: RestoreService;
  readonly searchSuggestions: SearchSuggestionService;

  private constructor(context: Context) {
    const database = new RdbDatabase(context);
    const repository = new ItemRepository(new ItemDao(database));
    const batchRepository = new BatchRepository(new BatchDao(database));
    const locationRepository = new LocationRepository(database);
    const categoryRepository = new CategoryRepository(database);
    const traceRepository = new TraceEventRepository(database);
    const validator = new ItemValidator();
    const expiryService = new ExpiryService();
    const listItems = new ItemListService(repository, expiryService);

    this.systemFeatures = new SystemFeatureService(context);
    this.backupProgress = new BackupProgressService(this.systemFeatures);
    this.database = database;
    this.repository = repository;
    this.createItem = new ItemCreateService(repository, validator);
    this.listItems = listItems;
    this.detailItem = new ItemDetailService(repository);
    this.updateItem = new ItemUpdateService(repository, validator, () => Date.now(), batchRepository);
    const preferenceRepository = new PreferenceRepository(context);
    const preferenceService = new PreferenceService(preferenceRepository);
    this.appIcon = new AppIconService(new SystemAppIconAdapter());
    const reminderRepository = new ReminderRepository(new ReminderDao(database));
    const reminderService = new ReminderService(reminderRepository, preferenceService, new SystemReminderAdapter(), repository);
    const assetRepository = new AssetRepository(new AssetDao(database));
    const assetStorage = new LocalAssetStorage(context);
    const photoService = new PhotoService(assetRepository, repository, assetStorage);
    this.deleteItem = new ItemDeleteService(repository, reminderService, photoService);
    this.searchItems = new ItemSearchService(repository, listItems);
    const thresholdRepository = new StockThresholdRepository(database);
    this.homeSummary = new HomeSummaryService(repository, expiryService, thresholdRepository);
    this.preferences = preferenceService;
    this.reminders = reminderService;
    this.photos = photoService;
    this.photoMaintenance = new PhotoMaintenanceService(assetRepository, repository, assetStorage);
    this.imageSource = new SystemImageSourceAdapter();

    this.photoSearch = new PhotoSearchService(context, repository, assetRepository, this.searchItems, this.systemFeatures);
    this.scan = new ScanService(new SystemScanAdapter());
    this.batches = new BatchService(batchRepository, repository);
    this.lowStock = new LowStockService(thresholdRepository, repository);
    this.lowStockReminder = new LowStockReminderService();
    this.lending = new LendingService(traceRepository, repository);
    this.formSnapshot = new FormSnapshotProvider(this.homeSummary, reminderRepository, this.lending);
    this.locations = new LocationService(locationRepository, repository, () => Date.now(), batchRepository);
    this.locationLabels = new LocationLabelService(new LocationLabelRepository(database), this.locations);
    this.categories = new CategoryService(categoryRepository);
    this.exportData = new ExportService(repository, batchRepository, locationRepository, categoryRepository, traceRepository);
    this.importData = new ImportService();
    this.backup = new BackupService(this.exportData);
    this.portableBackup = new PortableBackupService(this.exportData, thresholdRepository, assetRepository,
      new PortableFileStore(context), database, reminderService, this.backupProgress);
    this.restore = new RestoreService(this.importData);
    this.searchSuggestions = new SearchSuggestionService(new SearchHistoryRepository(database), repository);
  }

  static configure(context: Context): void {
    if (AppServices.instance === undefined) {
      AppServices.instance = new AppServices(context.getApplicationContext());
    }
  }

  static get(): AppServices {
    if (AppServices.instance === undefined) {
      throw new AppError(AppErrorCode.DATABASE_INIT, '应用服务尚未初始化');
    }
    return AppServices.instance;
  }
}
