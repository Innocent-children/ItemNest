import { speechRecognizer } from '@kit.CoreSpeechKit';
import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { uuid } from '../model/Models';

@Component
export struct VoicePanel {
  target: string = '名称';
  currentValue: string = '';
  maxLength: number = 80;
  append: boolean = false;
  registerStop: (stop?: () => void) => void = () => {};
  onAdopt: (text: string) => void = () => {};
  onCancel: () => void = () => {};
  @State candidate: string = '';
  @State state: string = '正在准备麦克风…';
  @State recording: boolean = false;
  @StorageProp('backgroundAt') @Watch('backgroundChanged') backgroundAt: number = 0;
  private engine?: speechRecognizer.SpeechRecognitionEngine;
  private session: string = '';
  private alive: boolean = true;
  private timer: number = -1;
  private generation: number = 0;
  private settled: boolean = false;
  aboutToAppear(): void {
    this.registerStop(() => { this.settled = true; this.cancelSession(); });
    this.start();
  }
  aboutToDisappear(): void { this.registerStop(undefined); this.alive = false; this.cancelSession(); try { this.engine?.shutdown(); } catch (_) {} }
  backgroundChanged(): void { this.cancel(); }
  private cancelSession(): void {
    this.generation++; clearTimeout(this.timer); this.recording = false;
    const session = this.session; this.session = '';
    if (session) { try { this.engine?.cancel(session); } catch (_) {} }
  }
  private cancel(): void { if (this.settled) return; this.settled = true; this.cancelSession(); this.onCancel(); }
  private fail(message: string): void {
    if (!this.alive || this.settled) return;
    this.getUIContext().getPromptAction().showToast({ message }); this.cancel();
  }
  private complete(): void {
    if (!this.alive || this.settled) return;
    const text = this.candidate.trim();
    if (!text) { this.fail('没有识别到文字，可以再试一次或直接打字'); return; }
    const value = this.append && this.currentValue ? this.currentValue + '\n' + text : text;
    if (Array.from(value).length > this.maxLength) { this.fail(`识别内容超过 ${this.maxLength} 字，原内容已保留，请分段输入`); return; }
    this.settled = true; this.cancelSession(); this.onAdopt(text);
  }
  private finish(): void {
    if (!this.recording || this.settled) return;
    this.recording = false; this.state = '正在整理文字…'; clearTimeout(this.timer);
    this.timer = setTimeout(() => this.fail('识别暂时没有完成，请重试或直接打字'), 10000);
    try { this.engine?.finish(this.session); } catch (_) { this.fail('语音识别未完成，请重试或直接打字'); }
  }
  private async start(): Promise<void> {
    const generation = ++this.generation;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const permission = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
      if (!this.alive || generation !== this.generation) return;
      if (permission.authResults[0] !== 0) { this.fail('允许使用麦克风后才能语音填写，也可以直接打字'); return; }
      const engine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 1, extraParams: { locate: 'CN', recognizerMode: 'short' } });
      if (!this.alive || generation !== this.generation) { engine.shutdown(); return; }
      this.engine = engine; this.session = uuid(); const expected = this.session;
      this.engine.setListener({
        onStart: (id: string) => { if (id === expected && id === this.session && this.alive) { this.recording = true; this.state = '正在听，说完后会自动填入'; } },
        onEvent: () => {},
        onResult: (id: string, result: speechRecognizer.SpeechRecognitionResult) => { if (id === this.session && this.alive && !this.settled) { this.candidate = result.result; if (result.isLast) this.complete(); } },
        onComplete: (id: string) => { if (id === this.session && this.alive) this.complete(); },
        onError: (id: string) => { if (id === this.session && this.alive) this.fail('暂时无法识别语音，请重试或直接打字'); }
      });
      this.timer = setTimeout(() => { if (this.recording) this.finish(); else this.fail('麦克风启动超时，请重试'); }, 30000);
      this.engine.startListening({ sessionId: this.session, audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 }, extraParams: { recognitionMode: 0, maxAudioDuration: 30000 } });
    } catch (_) { if (generation === this.generation) this.fail('暂时无法使用语音，请重试或直接打字'); }
  }
  build() {
    Column({ space: 12 }) {
      Text(this.target === '搜索词' ? '语音查找' : '语音填写' + this.target).fontSize(20).fontColor($r('app.color.text'))
      Text(this.state).fontSize(14).fontColor($r('app.color.primary'))
      if (this.candidate) { Text(this.candidate).fontSize(14).maxLines(3).fontColor($r('app.color.secondary')) }
      Row({ space: 12 }) {
        if (this.recording) { Button('说完了').height(48).onClick(() => this.finish()) }
        Button('取消').height(48).onClick(() => this.cancel())
      }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }
}
