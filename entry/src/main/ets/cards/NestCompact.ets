import { NestCard } from './NestCard';
import { CardContent } from './CardContent';

const storage = new LocalStorage(new CardContent(false, 'QUICK'));
@Entry(storage)
@Component
struct NestCompact {
  build() {
    Column() {
      NestCard()
    }.width('100%').height('100%')
  }
}
