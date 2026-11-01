import { NestCard } from './NestCard';
import { CardContent } from './CardContent';

const storage = new LocalStorage(new CardContent(true, 'COMMON'));
@Entry(storage)
@Component
struct NestWide {
  build() {
    Column() {
      NestCard()
    }.width('100%').height('100%')
  }
}
