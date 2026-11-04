// Report comment overlay — a small modal card used when TDLib wants free text to finish a report
// (C10 remainder / S12e). The page owns the state; this component is presentation only.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReportCommentOverlay {
  @Param title: string = '';
  @Param placeholder: string = '';
  @Param draft: string = '';
  @Param submitting: boolean = false;
  @Param cancelLabel: string = 'Cancel';
  @Param sendLabel: string = 'Send';
  @Event onDraftChange: (value: string) => void = (_value: string): void => {};
  @Event onCancel: () => void = (): void => {};
  @Event onSubmit: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TgUiTokens.COMPOSER_ATTACHMENT_SHEET_MASK)
        .onClick(() => {
          this.onCancel();
        })

      Column() {
        Text(this.title)
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
        TextInput({ text: this.draft, placeholder: this.placeholder })
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .height(44)
          .margin({ top: TgUiTokens.SPACE_8 })
          .onChange((value: string): void => {
            this.onDraftChange(value);
          })
        Row() {
          Button(this.cancelLabel)
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .height(36)
            .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
            .onClick(() => {
              this.onCancel();
            })
          Button(this.sendLabel)
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .height(36)
            .margin({ left: TgUiTokens.SPACE_12 })
            .enabled(!this.submitting)
            .onClick(() => {
              this.onSubmit();
            })
        }
        .justifyContent(FlexAlign.End)
        .width('100%')
        .margin({ top: TgUiTokens.SPACE_12 })
      }
      .width('86%')
      .padding(TgUiTokens.SPACE_16)
      .borderRadius(16)
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
