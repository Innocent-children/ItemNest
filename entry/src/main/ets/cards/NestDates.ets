import { NestCard } from './NestCard';
import { CardContent } from './CardContent';

const storage = new LocalStorage(new CardContent(false, 'DATES'));
@Entry(storage)
@Component
struct NestDates {
  build() {
    Column() {
      NestCard()
    }.width('100%').height('100%')
  }
}
