import { ExternalRequest } from '../model/SystemFeatures';

export class ExternalRequestParser {
  static parseUri(uri: string): ExternalRequest | undefined {
    if (uri.length > 4096) { return undefined; }
    const match = /^itemtrace:\/\/(item|location|function)\/([^?#]+)$/.exec(uri);
    if (match === null) { return undefined; }
    try {
      const id = decodeURIComponent(match[2]);
      if (id.length === 0 || id.length > 200 || /[\u0000-\u001f]/.test(id)) { return undefined; }
      if (match[1] === 'item') { return { action: 'item', itemId: id }; }
      if (match[1] === 'location') { return { action: 'location', locationId: id }; }
      return ExternalRequestParser.functionRequest(id);
    } catch (_) { return undefined; }
  }

  static functionRequest(action: string): ExternalRequest | undefined {
    return ['add', 'scan', 'camera', 'search', 'expiry', 'reminders', 'loans', 'backup', 'system'].includes(action) ?
      { action: action } : undefined;
  }

  static itemUri(id: string): string {
    return 'itemtrace://item/' + encodeURIComponent(id);
  }

  static publish(request: ExternalRequest): void {
    AppStorage.setOrCreate<string>('itemtrace.externalRequest', JSON.stringify(request));
    AppStorage.setOrCreate<number>('itemtrace.externalRevision',
      (AppStorage.get<number>('itemtrace.externalRevision') ?? 0) + 1);
  }
}
