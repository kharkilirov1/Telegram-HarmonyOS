@ComponentV2
export struct TypingIndicator {
  @Local dot1Scale: number = 0.4;
  @Local dot2Scale: number = 0.4;
  @Local dot3Scale: number = 0.4;
  @Param typingText: ResourceStr = 'typing';
  private intervalId: number = -1;
  private phase: number = 0;

  aboutToAppear(): void {
    this.startAnimation();
  }

  aboutToDisappear(): void {
    if (this.intervalId >= 0) {
      clearInterval(this.intervalId);
    }
  }

  build() {
    Row({ space: 2 }) {
      Circle()
        .width(5)
        .height(5)
        .fill($r('app.color.telegram_blue'))
        .scale({ x: this.dot1Scale, y: this.dot1Scale })

      Circle()
        .width(5)
        .height(5)
        .fill($r('app.color.telegram_blue'))
        .scale({ x: this.dot2Scale, y: this.dot2Scale })

      Circle()
        .width(5)
        .height(5)
        .fill($r('app.color.telegram_blue'))
        .scale({ x: this.dot3Scale, y: this.dot3Scale })

      Text(this.typingText)
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))
        .margin({ left: 2 })
    }
    .alignItems(VerticalAlign.Center)
  }

  private startAnimation(): void {
    this.intervalId = setInterval(() => {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.dot1Scale = this.phase === 0 ? 1.0 : 0.4;
        this.dot2Scale = this.phase === 1 ? 1.0 : 0.4;
        this.dot3Scale = this.phase === 2 ? 1.0 : 0.4;
      });
      this.phase = (this.phase + 1) % 3;
    }, 300);
  }
}
