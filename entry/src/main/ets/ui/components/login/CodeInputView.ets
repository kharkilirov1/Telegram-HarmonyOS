// CodeInputView — поле ввода кода с раздельными ячейками
// Референс: Telegram iOS CodeInputView
//
// iOS: CodeInputView с UITextField (hidden), визуальные ячейки для каждой цифры
// Auto-submit при заполнении всех ячеек

import { TgColorRes, TgSize } from '../../theme/TelegramTheme';

export type CodeInputType = 'numeric' | 'word' | 'phrase';

// ArkTS: class вместо interface для ForEach
class DigitItem {
  digit: string = '';
  isActive: boolean = false;
  index: number = 0;

  constructor(digit: string, isActive: boolean, index: number) {
    this.digit = digit;
    this.isActive = isActive;
    this.index = index;
  }
}

@Component
export struct CodeInputView {
  @Prop codeLength: number = 5;
  @Prop inputType: CodeInputType = 'numeric';
  @Link code: string;
  onComplete: (code: string) => void = (_code: string): void => {};
  onTextChanged: (text: string) => void = (_text: string): void => {};

  @State private isFocused: boolean = false;
  @State private shakeOffset: number = 0;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.inputType === 'numeric') {
        this.buildDigitCells()
      } else {
        this.buildTextField()
      }
    }
    .offset({ x: this.shakeOffset })
  }

  @Builder
  private buildDigitCells() {
    // iOS: CodeInputView — визуальные ячейки
    Row({ space: 12 }) {
      ForEach(this.getDigitArray(), (item: DigitItem) => {
        Column() {
          Text(item.digit)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgColorRes.PRIMARY)
            .textAlign(TextAlign.Center)
        }
        .width(42)
        .height(48)
        .borderRadius(8)
        .backgroundColor(TgColorRes.BACKGROUND_SECONDARY)
        .justifyContent(FlexAlign.Center)
        .border({
          width: item.isActive ? 2 : 1,
          color: item.isActive ? TgColorRes.ACCENT : TgColorRes.SEPARATOR
        })
      }, (item: DigitItem) => item.index.toString())
    }
    .justifyContent(FlexAlign.Center)

    // Реальное поле ввода (скрытое, как в iOS)
    TextInput({ text: this.code })
      .width('100%')
      .height(48)
      .opacity(0)
      .type(InputType.Number)
      .maxLength(this.codeLength)
      .onChange((value: string) => {
        // Фильтруем только цифры
        const filtered = value.replace(/[^0-9]/g, '');
        if (filtered.length <= this.codeLength) {
          this.code = filtered;
          this.onTextChanged(filtered);
          // iOS: auto-submit при полном заполнении
          if (filtered.length === this.codeLength) {
            this.onComplete(filtered);
          }
        }
      })
      .onFocus(() => { this.isFocused = true; })
      .onBlur(() => { this.isFocused = false; })
  }

  @Builder
  private buildTextField() {
    // iOS: для word/phrase — обычный TextFieldNode
    Column({ space: 0 }) {
      TextInput({ text: this.code, placeholder: this.inputType === 'word' ? 'Enter word' : 'Enter phrase' })
        .width('100%')
        .height(44)
        .fontSize(TgSize.INPUT_FONT)
        .fontColor(TgColorRes.PRIMARY)
        .placeholderColor(TgColorRes.PLACEHOLDER)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => {
          this.code = value;
          this.onTextChanged(value);
        })

      // iOS: codeSeparatorNode
      Divider()
        .width('100%')
        .height(0.5)
        .color(this.isFocused ? TgColorRes.ACCENT : TgColorRes.SEPARATOR)
    }
    .padding({ left: TgSize.SIDE_INSET, right: TgSize.SIDE_INSET })
  }

  // Shake анимация при ошибке
  animateError(): void {
    const sequence: number[] = [12, -12, 8, -8, 4, -4, 0];
    let delay = 0;
    for (let i = 0; i < sequence.length; i++) {
      const offset = sequence[i];
      setTimeout(() => { this.shakeOffset = offset; }, delay);
      delay += 50;
    }
  }

  // Сброс кода
  resetCode(): void {
    this.code = '';
  }

  private getDigitArray(): DigitItem[] {
    const result: DigitItem[] = [];
    for (let i = 0; i < this.codeLength; i++) {
      const digit = i < this.code.length ? this.code.charAt(i) : '';
      const isActive = i === this.code.length && this.isFocused;
      result.push(new DigitItem(digit, isActive, i));
    }
    return result;
  }
}
