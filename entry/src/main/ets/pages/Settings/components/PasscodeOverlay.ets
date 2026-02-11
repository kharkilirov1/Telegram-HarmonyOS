@ComponentV2
export struct PasscodeOverlay {
  @Param title: Resource = $r('app.string.enter_passcode');
  @Param passcodeLength: number = 4;
  @Param enteredPasscodeLength: number = 0;
  @Param passcodeError: string = '';

  @Event onBack: () => void = () => {};
  @Event onDigit: (digit: string) => void = (_digit: string) => {};
  @Event onDelete: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => {
            this.onBack();
          })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      Blank().height(40)

      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 32 })

      Row({ space: 16 }) {
        ForEach(this.getDotArray(), (index: number) => {
          Circle()
            .width(14)
            .height(14)
            .fill(index < this.enteredPasscodeLength
              ? $r('app.color.telegram_blue')
              : Color.Transparent)
            .stroke($r('app.color.telegram_blue'))
            .strokeWidth(1.5)
            .accessibilityText($r('app.string.accessibility_passcode_dot'))
        }, (index: number) => index.toString())
      }
      .margin({ bottom: 12 })

      if (this.passcodeError.length > 0) {
        Text(this.passcodeError)
          .fontSize(14)
          .fontColor($r('app.color.error_red'))
          .margin({ top: 4, bottom: 4 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      } else {
        Blank().height(21)
      }

      Blank()

      Column({ space: 12 }) {
        Row({ space: 24 }) {
          this.numKey('1')
          this.numKey('2')
          this.numKey('3')
        }

        Row({ space: 24 }) {
          this.numKey('4')
          this.numKey('5')
          this.numKey('6')
        }

        Row({ space: 24 }) {
          this.numKey('7')
          this.numKey('8')
          this.numKey('9')
        }

        Row({ space: 24 }) {
          Column()
            .width(72)
            .height(72)

          this.numKey('0')

          Column() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
          }
          .width(72)
          .height(72)
          .borderRadius(36)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.onDelete();
          })
        }
      }
      .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
    .alignItems(HorizontalAlign.Center)
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }

  @Builder
  private numKey(digit: string) {
    Column() {
      Text(digit)
        .fontSize(28)
        .fontWeight(FontWeight.Regular)
        .fontColor($r('app.color.text_primary'))
    }
    .width(72)
    .height(72)
    .borderRadius(36)
    .backgroundColor($r('app.color.background_secondary'))
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onDigit(digit);
    })
  }

  private getDotArray(): number[] {
    const dots: number[] = [];
    for (let i = 0; i < this.passcodeLength; i++) {
      dots.push(i);
    }
    return dots;
  }
}
