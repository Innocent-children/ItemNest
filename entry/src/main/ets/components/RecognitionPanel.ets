import { PhotoViewer } from './PhotoViewer';
import { CaptureDraft } from '../model/SystemFeatures';
import { AppServices } from '../service/AppServices';

@Component
export struct RecognitionPanel {
  @Prop @Watch('reset') photoUri: string = '';
  @Prop inputEnabled: boolean = true;
  onApply: (draft: CaptureDraft) => void = () => {};
  @State private showPhoto: boolean = false;
  @State private recognizing: boolean = false;
  @State private text: string = '';
  @State private name: string = '';
  @State private productionDate: string = '';
  @State private expirationDate: string = '';
  @State private shelfLife: string = '';
  @State private dates: string[] = [];
  @State private notice: string = '';
  private generation: number = 0;

  aboutToAppear(): void { if (this.photoUri.length > 0) { this.recognize(); } }

  aboutToDisappear(): void { this.generation++; }

  private reset(): void {
    this.generation++;
    this.text = ''; this.name = ''; this.dates = []; this.notice = '';
    this.productionDate = ''; this.expirationDate = ''; this.shelfLife = ''; this.recognizing = false;
    if (this.photoUri.length > 0) { this.recognize(); }
  }

  build() {
    Column({ space: 12 }) {
      Button(this.recognizing ? '正在识别包装文字…' : '识别照片中的名称和日期')
        .enabled(this.inputEnabled && this.photoUri.length > 0 && !this.recognizing)
        .onClick(() => this.recognize())
      if (this.notice.length > 0) {
        Text(this.notice).fontSize(13).fontColor($r('app.color.text_secondary')).width('100%')
      }
      if (this.text.length > 0) {
        Image(this.photoUri).width('100%').height(260).objectFit(ImageFit.Contain)
          .accessibilityText('打开原图，放大检查包装文字').onClick(() => this.showPhoto = true)
        TextInput({ text: this.name, placeholder: '识别出的名称，可修改' }).maxLength(80)
          .onChange((value: string) => this.name = value)
        Text('生产日期：' + (this.productionDate || '未识别') + '　保质期：' + (this.shelfLife || '未识别'))
          .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%')
        TextInput({ text: this.expirationDate, placeholder: '确认到期日期，例如 2026-12-31' })
          .maxLength(10).onChange((value: string) => this.expirationDate = value)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.dates, (date: string) => {
            Button('选为到期日：' + date).fontSize(12).margin(4)
              .onClick(() => this.expirationDate = date)
          }, (date: string) => date)
        }
        Text(this.text).fontSize(13).fontColor($r('app.color.text_secondary')).copyOption(CopyOptions.LocalDevice)
          .width('100%')
        Button('将确认的内容填入表单').enabled(this.inputEnabled).onClick(() => this.apply())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .bindContentCover($$this.showPhoto, this.photoPreview)
  }

  @Builder
  private photoPreview() { PhotoViewer({ path: this.photoUri, visible: $showPhoto }) }

  private async recognize(): Promise<void> {
    const generation = ++this.generation;
    this.recognizing = true;
    this.notice = '';
    const result = await AppServices.get().textRecognition.recognize(this.photoUri);
    if (generation !== this.generation) { return; }
    this.recognizing = false;
    if (!result.ok) { this.notice = result.getError().message; return; }
    const draft = AppServices.get().captureDraft.parse(result.getData());
    this.text = draft.text;
    this.name = draft.name;
    this.productionDate = draft.productionDate;
    this.expirationDate = draft.expirationDate;
    this.shelfLife = draft.shelfLife;
    this.dates = draft.dateCandidates;
    this.notice = this.text.length === 0 ? '没有识别到文字，请换一张清晰的包装照片。' : draft.notice;
  }

  private apply(): void {
    if (this.expirationDate.length > 0 && AppServices.get().captureDraft.normalizeDate(this.expirationDate).length === 0) {
      this.notice = '请填写有效的到期日期，或清空日期后手动补充。'; return;
    }
    this.onApply({ name: this.name, productionDate: this.productionDate, expirationDate: this.expirationDate,
      shelfLife: this.shelfLife, text: this.text, dateCandidates: this.dates, notice: '' });
    this.notice = '内容已填入，点击表单保存后生效。';
  }
}
