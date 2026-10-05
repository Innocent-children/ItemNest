@Component
export struct AmbientParticles {
  @StorageLink('itemtrace.reduceAnimation') @Watch('syncAnimation') private reduceAnimation: boolean = false;
  @StorageLink('itemtrace.uiForeground') @Watch('syncAnimation') private foreground: boolean = true;
  @Prop @Watch('syncAnimation') active: boolean = true;
  @State private running: boolean = false;
  private stopTimer: number = -1;
  private visibleInViewport: boolean = true;

  aboutToAppear(): void {
    this.syncAnimation();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.stopTimer !== -1) {
      clearTimeout(this.stopTimer);
      this.stopTimer = -1;
    }
    this.running = false;
  }

  private syncAnimation(): void {
    this.stop();
    if (!this.active || !this.foreground || this.reduceAnimation || !this.visibleInViewport) {
      return;
    }
    this.running = true;
    // A short ambient entrance, never an endless background render loop.
    this.stopTimer = setTimeout(() => {
      this.running = false;
      this.stopTimer = -1;
    }, 7200);
  }

  build() {
    Stack() {
      if (this.running) {
        Particle({ particles: [{
          emitter: {
            particle: { type: ParticleType.POINT, config: { radius: 1.8 }, count: 48,
              lifetime: 3000, lifetimeRange: 600 },
            emitRate: 12, shape: ParticleEmitterShape.RECTANGLE,
            position: ['25%', 0], size: ['75%', '100%']
          },
          color: { range: [$r('app.color.particle_mint'), Color.White] },
          opacity: { range: [0.2, 0.65], updater: { type: ParticleUpdater.CURVE, config: [
            { from: 0, to: 0.65, startMillis: 0, endMillis: 500, curve: Curve.EaseOut },
            { from: 0.65, to: 0, startMillis: 500, endMillis: 2400, curve: Curve.EaseIn }
          ] } },
          scale: { range: [0.6, 1.3] },
          velocity: { speed: [5, 14], angle: [235, 305] }
        }] })
          .width('100%')
          .height('100%')
          .rippleFields([{ amplitude: 12, wavelength: 180, waveSpeed: 45, attenuation: 0.2,
            center: { x: 220, y: 80 }, region: { shape: DisturbanceFieldShape.RECT,
              position: { x: 200, y: 100 }, size: { width: 400, height: 280 } } }])
      }
    }
    .width('100%')
    .height(300)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no')
    .onVisibleAreaChange([0, 0.2], (visible: boolean, ratio: number) => {
      const inViewport = visible && ratio > 0;
      if (this.visibleInViewport !== inViewport) {
        this.visibleInViewport = inViewport;
        this.syncAnimation();
      }
    })
  }
}
