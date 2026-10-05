@Component
export struct DeleteConfirmDialog {
  @Link visible: boolean;
  @Link confirmed: boolean;
  @Prop title: string = '确认删除物品？';
  @Prop description: string = '删除后不可恢复。';
  @Prop confirmText: string = '确认删除';
  private opening: boolean = false;

  build() {
    if (this.visible) {
      Row().width(0).height(0).accessibilityLevel('no')
        .onAppear(() => this.openDialog())
    }
  }

  /**
   * 等待本次标题和描述传入后再打开系统弹窗，只有点击确认才触发操作。
   */
  private async openDialog(): Promise<void> {
    if (!this.visible || this.opening) { return; }
    this.opening = true;
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: this.title, message: this.description,
        buttons: [
          { text: '取消', color: $r('app.color.text_secondary') },
          { text: this.confirmText, color: $r('app.color.status_danger') }
        ]
      });
      this.visible = false;
      if (result.index === 1) { this.confirmed = true; }
    } catch (_) {
      this.visible = false;
    } finally {
      this.opening = false;
    }
  }
}
