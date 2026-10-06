import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { textSearchImage } from '@kit.CoreVisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ItemRepositoryPort } from '../data/repository/ItemRepository';
import { AssetRepositoryPort } from '../data/repository/AssetRepository';
import { ItemQuery } from '../model/ItemQuery';
import { ItemSummary } from '../model/Item';
import { ItemSearchService } from './ItemSearchService';
import { SystemFeatureService } from './SystemFeatureService';
import { AppError, AppErrorCode } from '../common/AppError';
import { Result, failure, success } from '../common/Result';

interface PhotoIndexEntry {
  itemId: string;
  path: string;
}

/**
 * 只索引物品当前引用的照片，路径与物品的关系每次按数据库重新核对。
 */
export class PhotoSearchService {
  private context: Context;
  private items: ItemRepositoryPort;
  private assets: AssetRepositoryPort;
  private searchItems: ItemSearchService;
  private settings: SystemFeatureService;
  private searchGeneration: number = 0;
  private queue: Promise<void> = Promise.resolve();
  private readonly scope: string = 'ItemTracePhotos';

  constructor(context: Context, items: ItemRepositoryPort, assets: AssetRepositoryPort, searchItems: ItemSearchService,
    settings: SystemFeatureService) {
    this.context = context;
    this.items = items;
    this.assets = assets;
    this.searchItems = searchItems;
    this.settings = settings;
  }

  supported(): boolean {
    return canIUse('SystemCapability.AI.Vision.VisionBase');
  }

  async search(query: ItemQuery): Promise<Result<ItemSummary[]>> {
    const generation = ++this.searchGeneration;
    const previous = this.queue;
    let release: () => void = () => {};
    this.queue = new Promise<void>((resolve: () => void) => { release = resolve; });
    await previous;
    let initialized = false;
    try {
      if (generation !== this.searchGeneration) {
        return failure(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '已跳过旧的搜索请求'));
      }
      if (!this.supported() || !(await this.settings.get()).photoSearchEnabled) {
        return failure(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '照片描述搜索未开启，或设备暂不支持视觉服务'));
      }
      if (query.name.trim().length === 0 || query.name.length > 100) {
        return failure(new AppError(AppErrorCode.VALIDATION, '请输入 1 至 100 个字符的外观描述'));
      }
      initialized = await textSearchImage.init();
      if (!initialized) { throw new Error('unavailable'); }
      const entries = await this.synchronize();
      const matches = await textSearchImage.search(query.name.trim(), this.scope, 20);
      const allowed = await this.searchItems.search(new ItemQuery('', query.locationPath, query.category));
      if (!allowed.ok) { return failure(allowed.getError()); }
      const results: ItemSummary[] = [];
      for (const match of matches) {
        const entry = entries.find((candidate: PhotoIndexEntry) => candidate.path === match.imagePath);
        const item = allowed.getData().items.find((candidate: ItemSummary) => candidate.id === entry?.itemId);
        if (item !== undefined && !results.some((candidate: ItemSummary) => candidate.id === item.id)) {
          item.photoPath = entry?.path;
          results.push(item);
        }
      }
      return success(results);
    } catch (error) {
      if ((error as BusinessError).code === 1013100003 && this.supported()) {
        try {
          await textSearchImage.clearData();
          const store = await preferences.getPreferences(this.context, 'itemtrace_photo_index');
          await store.delete('photoIndex');
          await store.flush();
        } catch (_) {}
      }
      return failure(new AppError(AppErrorCode.SYSTEM_UNAVAILABLE, '照片搜索暂不可用，请重试或使用名称搜索'));
    } finally {
      if (initialized) { try { await textSearchImage.release(); } catch (_) {} }
      release();
    }
  }

  async refresh(): Promise<void> {
    const previous = this.queue;
    let release: () => void = () => {};
    this.queue = new Promise<void>((resolve: () => void) => { release = resolve; });
    await previous;
    let initialized = false;
    try {
      if (!this.supported()) { return; }
      initialized = await textSearchImage.init();
      if (!initialized) { return; }
      if (!(await this.settings.get()).photoSearchEnabled) {
        await textSearchImage.clearData();
        const store = await preferences.getPreferences(this.context, 'itemtrace_photo_index');
        await store.delete('photoIndex');
        await store.flush();
      } else { await this.synchronize(); }
    } catch (_) {
      // 失败后保留已完成的记录，下一次数据变化或查询会重新核对。
    } finally {
      if (initialized) { try { await textSearchImage.release(); } catch (_) {} }
      release();
    }
  }

  private async synchronize(): Promise<PhotoIndexEntry[]> {
    const listed = await this.items.listAll();
    if (!listed.ok) { throw listed.getError(); }
    const entries: PhotoIndexEntry[] = [];
    for (const item of listed.getData()) {
      if (item.photoLocalId === undefined) { continue; }
      const asset = await this.assets.getById(item.photoLocalId);
      if (!asset.ok) { throw asset.getError(); }
      if (asset.getData()?.itemId === item.id) {
        entries.push({ itemId: item.id, path: asset.getData()!.localPath });
      }
    }
    const store = await preferences.getPreferences(this.context, 'itemtrace_photo_index');
    const previous = JSON.parse(store.getSync('photoIndex', '[]') as string) as PhotoIndexEntry[];
    for (const old of previous) {
      if (!entries.some((entry: PhotoIndexEntry) => entry.path === old.path)) {
        if (!await textSearchImage.deleteImage(old.path, this.scope)) { throw new Error('delete failed'); }
      }
    }
    for (const entry of entries) {
      if (!previous.some((old: PhotoIndexEntry) => old.path === entry.path)) {
        if (!await textSearchImage.insertImage(entry.path, this.scope)) { throw new Error('insert failed'); }
      }
    }
    await store.put('photoIndex', JSON.stringify(entries));
    await store.flush();
    return entries;
  }
}
