import { relationalStore } from '@kit.ArkData';
import { LocationLabel } from '../../model/LocationLabel';
import { RdbDatabase } from '../rdb/RdbDatabase';
import { ResultSetReader } from '../rdb/ResultSetReader';

export class LocationLabelRepository {
  private database: RdbDatabase;
  constructor(database: RdbDatabase) { this.database = database; }

  async list(): Promise<LocationLabel[]> {
    const store = await this.database.requireStore();
    const rows = await store.querySql('SELECT token, location_id FROM location_label ORDER BY token');
    const labels: LocationLabel[] = [];
    try {
      while (ResultSetReader.goToNextRow(rows)) {
        labels.push({ token: ResultSetReader.readString(rows, 'token') ?? '',
          locationId: ResultSetReader.readString(rows, 'location_id') ?? '' });
      }
    } finally { ResultSetReader.close(rows); }
    return labels;
  }

  async save(label: LocationLabel): Promise<void> {
    await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
      await store.execute('INSERT OR REPLACE INTO location_label (token, location_id) VALUES (?, ?)', [label.token, label.locationId]);
    });
  }

  async remove(token: string): Promise<void> {
    await this.database.transaction(async (store: relationalStore.Transaction): Promise<void> => {
      await store.delete(new relationalStore.RdbPredicates('location_label').equalTo('token', token));
    });
  }
}
