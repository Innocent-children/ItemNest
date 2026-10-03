import { Context } from '@kit.AbilityKit';
import { Result } from '../common/Result';
import { ScanAdapter } from './adapter/ScanAdapter';

export class ScanService {
  private readonly adapter: ScanAdapter;

  constructor(adapter: ScanAdapter) {
    this.adapter = adapter;
  }

  async scan(context: Context): Promise<Result<string | undefined>> {
    return this.adapter.scan(context);
  }
}
