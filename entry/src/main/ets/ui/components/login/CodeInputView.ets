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

@ComponentV2
export struct CodeInputView {
  // Стабильный id скрытого/текстового поля ввода — цель автофокуса при появлении шага.
  private static readonly CODE_INPUT_ID: string = 'login_code_input';

  @Param codeLength: number = 5;
  @Param inputType: CodeInputType = 'numeric';
  @Param code: string = '';
  @Event onCodeChange: (code: string) => void = (_code: string): void => {};
  @Event onComplete: (code: string) => void = (_code: string): void => {};
  @Event onTextChanged: (text: string) => void = (_text: string): void => {};

  @Local private isFocused: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.inputType === 'numeric') {
        this.buildDigitCells()
      } else {
        this.buildTextField()
      }
    }
    .onAppear(() => { this.focusInput(); })
  }

  // Фокусирует поле ввода кода и поднимает софт-клавиатуру при появлении шага.
  // Для numeric-режима реальный ввод идёт в скрытом (opacity 0) TextInput — без фокуса
  // тап по невидимому полю ненадёжен, поэтому фокусируем программно.
  private focusInput(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(CodeInputView.CODE_INPUT_ID);
    } catch (e) {
      // requestFocus бросает, если узел ещё не готов — не критично для UX.
    }
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
      }, (item: DigitItem) => `${item.index}_${item.digit}_${item.isActive ? '1' : '0'}`)
    }
    .justifyContent(FlexAlign.Center)

    // Реальное поле ввода (скрытое, как в iOS)
    TextInput({ text: this.code })
      .id(CodeInputView.CODE_INPUT_ID)
      .width('100%')
      .height(TgUiTokens.LOGIN_CODE_CELL_HEIGHT)
      .opacity(0)
      .type(InputType.Number)
      .maxLength(this.codeLength)
      .onChange((value: string) => {
        // Фильтруем только цифры
        const filtered = value.replace(/[^0-9]/g, '');
        if (filtered.length <= this.codeLength) {
          this.onCodeChange(filtered);
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
        .id(CodeInputView.CODE_INPUT_ID)
        .width('100%')
        .height(TgUiTokens.LOGIN_TEXT_INPUT_HEIGHT)
        .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
        .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
        .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => {
          this.onCodeChange(value);
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

  // Сброс кода
  resetCode(): void {
    this.onCodeChange('');
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
