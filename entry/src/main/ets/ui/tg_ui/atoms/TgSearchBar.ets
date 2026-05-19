import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgSearchBar {
  @Param value: string = '';
  @Param placeholder: string = 'Search';
  @Param showClearButton: boolean = true;
  @Param isActive: boolean = false;
  @Param showCancelButton: boolean = false;
  @Param cancelText: string = 'Cancel';

  @Event onTextChange: (text: string) => void = (_: string): void => {};
  @Event onSubmit: (text: string) => void = (_: string): void => {};
  @Event onClearPress: () => void = (): void => {};
  @Event onFocusChange: (isFocused: boolean) => void = (_: boolean): void => {};
  @Event onCancelPress: () => void = (): void => {};
  @Local internalValue: string = '';
  private inputController: TextInputController = new TextInputController();

  aboutToAppear(): void {
    this.internalValue = this.value;
  }

  @Monitor('value')
  onValueChange(): void {
    this.internalValue = this.value;
  }

  private hasValue(): boolean {
    return this.internalValue.trim().length > 0;
  }

  private shouldShowCancel(): boolean {
    return this.showCancelButton || this.isActive;
  }

  private handleClear(): void {
    if (!this.hasValue()) {
      return;
    }
    this.internalValue = '';
    this.onTextChange('');
    this.onClearPress();
  }

  private handleCancel(): void {
    this.inputController.stopEditing();
    if (this.hasValue()) {
      this.internalValue = '';
      this.onTextChange('');
    }
    this.onCancelPress();
    this.onFocusChange(false);
  }

  @Builder
  private buildInputCapsule() {
    Row({ space: TgUiTokens.SEARCH_BAR_ICON_GAP }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_SEARCH,
        iconSize: TgUiTokens.SEARCH_BAR_ICON_SIZE,
        tintColor: TgUiTokens.SEARCH_BAR_ICON_COLOR
      })

      TextInput({ controller: this.inputController, text: this.value, placeholder: this.placeholder })
        .layoutWeight(1)
        .height('100%')
        .fontSize(TgUiTokens.SEARCH_BAR_FONT_SIZE)
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .caretColor(TgUiTokens.COLOR_ICON_PRIMARY)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0, top: 0, bottom: 0 })
        .margin(0)
        .maxLines(1)
        .type(InputType.Normal)
        .onChange((value: string) => {
          this.internalValue = value;
          this.onTextChange(value);
        })
        .onSubmit(() => {
          this.onSubmit(this.internalValue);
        })
        .onFocus(() => {
          this.onFocusChange(true);
        })
        .onBlur(() => {
          this.onFocusChange(false);
        })
        .enterKeyType(EnterKeyType.Search)
        .enableKeyboardOnFocus(true)

      if (this.showClearButton && this.hasValue()) {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.SEARCH_BAR_CLEAR_ICON_SIZE,
            tintColor: TgUiTokens.SEARCH_BAR_ICON_COLOR
          })
        }
        .width(TgUiTokens.SEARCH_BAR_CLEAR_TOUCH_SIZE)
        .height(TgUiTokens.SEARCH_BAR_CLEAR_TOUCH_SIZE)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityGroup(true)
        .accessibilityDescription('Clear')
        .onClick(() => {
          this.handleClear();
        })
      }
    }
    .width('100%')
    .height(TgUiTokens.SEARCH_BAR_HEIGHT)
    .padding({
      left: TgUiTokens.SEARCH_BAR_INNER_PADDING_H,
      right: TgUiTokens.SEARCH_BAR_INNER_PADDING_H
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
    .borderRadius(TgUiTokens.SEARCH_BAR_RADIUS)
    .clip(true)
  }

  @Builder
  private buildCancelButton() {
    if (this.shouldShowCancel()) {
      Row() {
        Text(this.cancelText)
          .fontSize(TgUiTokens.SEARCH_BAR_CANCEL_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
          .maxLines(1)
      }
      .constraintSize({ minWidth: TgUiTokens.SEARCH_BAR_CANCEL_MIN_WIDTH })
      .height(TgUiTokens.SEARCH_BAR_HEIGHT)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.handleCancel();
      })
    }
  }

  build() {
    Row({ space: this.shouldShowCancel() ? TgUiTokens.SEARCH_BAR_CANCEL_GAP : 0 }) {
      Row() {
        this.buildInputCapsule()
      }
      .layoutWeight(1)

      this.buildCancelButton()
    }
    .width('100%')
    .animation({ duration: TgUiTokens.SEARCH_BAR_ACTIVE_ANIM_DURATION, curve: Curve.EaseInOut })
  }
}
