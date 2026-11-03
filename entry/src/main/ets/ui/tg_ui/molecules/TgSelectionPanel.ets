// TgSelectionPanel — message-selection bar that replaces the composer while messages are selected
// (C9 / iOS ChatMessageSelectionInputPanelNode). Text actions only for now: the icon set has no copy
// glyph, so all three actions share the same text-button treatment instead of an icon/text mix.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgSelectionPanel {
  // Number of selected messages; the label comes from the caller already formatted.
  @Param title: string = '';
  @Param canCopy: boolean = true;
  @Param canForward: boolean = true;
  @Param canDelete: boolean = true;
  @Event onClose: () => void = () => {};
  @Event onCopy: () => void = () => {};
  @Event onForward: () => void = () => {};
  @Event onDelete: () => void = () => {};

  @Builder
  private buildAction(label: Resource, enabled: boolean, action: () => void) {
    Text(label)
      .fontSize(TgUiTokens.SELECTION_PANEL_ACTION_TEXT_SIZE)
      .fontWeight(TgUiTokens.SELECTION_PANEL_ACTION_TEXT_WEIGHT)
      .fontColor(enabled ? TgUiTokens.COLOR_TEXT_TITLE : TgUiTokens.COLOR_TEXT_META)
      .maxLines(1)
      .padding({
        left: TgUiTokens.SELECTION_PANEL_ACTION_PADDING_H,
        right: TgUiTokens.SELECTION_PANEL_ACTION_PADDING_H
      })
      .enabled(enabled)
      .onClick(() => {
        if (enabled) {
          action();
        }
      })
  }

  build() {
    Row() {
      Image($r('app.media.ic_close'))
        .width(TgUiTokens.SELECTION_PANEL_CLOSE_ICON_SIZE)
        .height(TgUiTokens.SELECTION_PANEL_CLOSE_ICON_SIZE)
        .margin({ right: TgUiTokens.SELECTION_PANEL_ACTION_GAP })
        .onClick(() => {
          this.onClose();
        })

      Text(this.title)
        .fontSize(TgUiTokens.SELECTION_PANEL_ACTION_TEXT_SIZE)
        .fontWeight(TgUiTokens.SELECTION_PANEL_ACTION_TEXT_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: TgUiTokens.SPACE_4 })

      this.buildAction($r('app.string.action_copy'), this.canCopy, () => {
        this.onCopy();
      })
      this.buildAction($r('app.string.action_forward'), this.canForward, () => {
        this.onForward();
      })
      this.buildAction($r('app.string.action_delete'), this.canDelete, () => {
        this.onDelete();
      })
    }
    .width('100%')
    .height(TgUiTokens.SELECTION_PANEL_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_8, right: TgUiTokens.SPACE_8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.SELECTION_PANEL_BG)
  }
}
