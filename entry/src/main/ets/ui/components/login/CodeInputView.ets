// CodeInputView — поле ввода кода с раздельными ячейками
// Референс: Telegram iOS CodeInputView
//
// iOS: CodeInputView с UITextField (hidden), визуальные ячейки для каждой цифры
// Auto-submit при заполнении всех ячеек

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { getString } from '../../../core/utils/AppResource';

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
    Row({ space: TgUiTokens.LOGIN_CODE_CELL_GAP }) {
      ForEach(this.getDigitArray(), (item: DigitItem) => {
        Column() {
          Text(item.digit)
            .fontSize(TgUiTokens.LOGIN_CODE_CELL_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.LOGIN_CODE_CELL_TEXT_COLOR)
            .textAlign(TextAlign.Center)
        }
        .width(TgUiTokens.LOGIN_CODE_CELL_WIDTH)
        .height(TgUiTokens.LOGIN_CODE_CELL_HEIGHT)
        .borderRadius(TgUiTokens.LOGIN_CODE_CELL_RADIUS)
        .backgroundColor(TgUiTokens.LOGIN_CODE_CELL_BG)
        .justifyContent(FlexAlign.Center)
        .border({
          width: item.isActive ? TgUiTokens.LOGIN_CODE_CELL_BORDER_ACTIVE_WIDTH : TgUiTokens.LOGIN_CODE_CELL_BORDER_INACTIVE_WIDTH,
          color: item.isActive ? TgUiTokens.LOGIN_CODE_CELL_BORDER_ACTIVE : TgUiTokens.LOGIN_CODE_CELL_BORDER_INACTIVE
        })
      }, (item: DigitItem) => item.index.toString())
    }
    .justifyContent(FlexAlign.Center)

    // Реальное поле ввода (скрытое, как в iOS)
    TextInput({ text: this.code })
      .width('100%')
      .height(TgUiTokens.LOGIN_CODE_CELL_HEIGHT)
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
      TextInput({ text: this.code, placeholder: this.inputType === 'word' ? this.wordPlaceholder() : this.phrasePlaceholder() })
        .width('100%')
        .height(TgUiTokens.LOGIN_TEXT_INPUT_HEIGHT)
        .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
        .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
        .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => {
          this.code = value;
          this.onTextChanged(value);
        })

      // iOS: codeSeparatorNode
      Divider()
        .width('100%')
        .height(TgUiTokens.LOGIN_SEPARATOR_STROKE)
        .color(this.isFocused ? TgUiTokens.LOGIN_CODE_CELL_BORDER_ACTIVE : TgUiTokens.LOGIN_SEPARATOR_COLOR)
    }
    .padding({ left: TgUiTokens.LOGIN_SIDE_INSET, right: TgUiTokens.LOGIN_SIDE_INSET })
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

  private wordPlaceholder(): string {
    const value = getString($r('app.string.code_input_enter_word').id);
    return value.length > 0 ? value : 'Enter word';
  }

  private phrasePlaceholder(): string {
    const value = getString($r('app.string.code_input_enter_phrase').id);
    return value.length > 0 ? value : 'Enter phrase';
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
