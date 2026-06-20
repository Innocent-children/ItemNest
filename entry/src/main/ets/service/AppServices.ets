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
    this.deleteItem = new ItemDeleteService(repository);
    this.searchItems = new ItemSearchService(repository, listItems);
    this.homeSummary = new HomeSummaryService(repository, expiryService);
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
