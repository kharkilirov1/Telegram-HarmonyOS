// TgSelectionPanel — message-selection bar that replaces the composer while messages are selected
// (C9 / iOS ChatMessageSelectionInputPanelNode).
//
// iOS geometry: ChatInputPanelNode.defaultHeight = 40; the node lays out circular 40x40 glass buttons
// spread across the panel width (ChatMessageSelectionInputPanelNode.swift:581-597) and dims them via
// HighlightTrackingButton on press: every action renders a circular icon button with the same size,
// shape and native press feedback; copy uses the doc.on.doc-shaped SVG like iOS.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ComponentV2
export struct TgSelectionPanel {
  // Number of selected messages; the label comes from the caller already formatted.
  @Param title: string = '';
  @Param canCopy: boolean = true;
  @Param canForward: boolean = true;
  @Param canDelete: boolean = true;
  // Report intent: the panel only offers it while TDLib waits for reported messages.
  @Param showReport: boolean = false;
  @Param reportLabel: Resource = $r('app.string.chat_actions_report');
  @Event onClose: () => void = () => {};
  @Event onCopy: () => void = () => {};
  @Event onForward: () => void = () => {};
  @Event onDelete: () => void = () => {};
  @Event onReport: () => void = () => {};

  @Builder
  private buildIconButton(icon: Resource, label: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(TgUiTokens.SELECTION_PANEL_BUTTON_ICON_SIZE)
        .height(TgUiTokens.SELECTION_PANEL_BUTTON_ICON_SIZE)
        .fillColor(enabled ? TgUiTokens.COLOR_TEXT_TITLE : TgUiTokens.COLOR_TEXT_META)
    }
    .width(TgUiTokens.SELECTION_PANEL_BUTTON_SIZE)
    .height(TgUiTokens.SELECTION_PANEL_BUTTON_SIZE)
    .backgroundColor(TgUiTokens.SELECTION_PANEL_BUTTON_BG)
    .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle())
    .enabled(enabled)
    .accessibilityText(label)
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
  }

  @Builder
  private buildGlyphButton(glyph: string, label: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Circle }) {
      Text(glyph)
        .fontSize(TgUiTokens.SELECTION_PANEL_BUTTON_ICON_SIZE)
        .fontColor(enabled ? TgUiTokens.COLOR_TEXT_TITLE : TgUiTokens.COLOR_TEXT_META)
    }
    .width(TgUiTokens.SELECTION_PANEL_BUTTON_SIZE)
    .height(TgUiTokens.SELECTION_PANEL_BUTTON_SIZE)
    .backgroundColor(TgUiTokens.SELECTION_PANEL_BUTTON_BG)
    .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle())
    .enabled(enabled)
    .accessibilityText(label)
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
  }

  build() {
    Row() {
      this.buildIconButton($r('app.media.ic_close'), $r('app.string.done'), true, () => {
        this.onClose();
      })

      Text(this.title)
        .fontSize(TgUiTokens.SELECTION_PANEL_TEXT_SIZE)
        .fontWeight(TgUiTokens.SELECTION_PANEL_TEXT_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row() {
        this.buildIconButton(TgUiTokens.SELECTION_PANEL_COPY_ICON, $r('app.string.action_copy'),
          this.canCopy, () => {
            this.onCopy();
          })
        this.buildIconButton($r('app.media.ic_forward'), $r('app.string.action_forward'), this.canForward, () => {
          this.onForward();
        })
        this.buildIconButton($r('app.media.ic_delete'), $r('app.string.action_delete'), this.canDelete, () => {
          this.onDelete();
        })
        if (this.showReport) {
          this.buildGlyphButton(TgUiTokens.SELECTION_PANEL_REPORT_GLYPH, this.reportLabel,
            this.canDelete, () => {
              this.onReport();
            })
        }
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: TgUiTokens.SELECTION_PANEL_ACTION_GAP })
    }
    .width('100%')
    .height(TgUiTokens.SELECTION_PANEL_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_4, right: TgUiTokens.SPACE_4 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.SELECTION_PANEL_BG)
    .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle())
  }
}
