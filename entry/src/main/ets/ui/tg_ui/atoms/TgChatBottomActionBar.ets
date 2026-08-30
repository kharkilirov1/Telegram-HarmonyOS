import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

export type TgChatBottomBarMode = 'action' | 'restricted';

// Telegram iOS bottom panel for chats where composing is unavailable
// (dispatcher: TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:13):
// - action mode — ChatChannelSubscriberInputPanelNode: glass rail with one
//   centered button; Join (accent) for not-joined chats, Mute/Unmute for a
//   joined broadcast channel
// - restricted mode — ChatRestrictedInputPanelNode: text-only panel with the
//   restriction reason (Conversation.DefaultRestrictedText)
@ComponentV2
export struct TgChatBottomActionBar {
  @Param mode: TgChatBottomBarMode = 'action';
  @Param actionText: string = '';
  @Param isActionAccent: boolean = false;
  @Param messageText: string = '';
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param bottomInset: number = 0;

  @Event onActionPress: () => void = (): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return TgGlassPolicy.supportsNativeMaterial() && this.useBlur();
  }

  private surfaceBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_SCROLL_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  private surfaceBackdropBlur(): number {
    return this.useBlur() ? TgUiTokens.GLASS_CAPSULE_BACKDROP_BLUR : 0;
  }

  private actionColor(): ResourceColor {
    return this.isActionAccent ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COLOR_TEXT_TITLE;
  }

  @Builder
  private buildActionContent() {
    Text(this.actionText)
      .fontSize(TgUiTokens.CHAT_BOTTOM_BAR_ACTION_FONT_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.actionColor())
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private buildRestrictedContent() {
    Text(this.messageText)
      .fontSize(TgUiTokens.CHAT_BOTTOM_BAR_RESTRICTED_FONT_SIZE)
      .fontWeight(FontWeight.Regular)
      .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      .maxLines(1)
      .textAlign(TextAlign.Center)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeSurface() {
    Row() {
      if (this.mode === 'action') {
        this.buildActionContent()
      } else {
        this.buildRestrictedContent()
      }
    }
    .width('100%')
    .height(TgUiTokens.CHAT_BOTTOM_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: this.mode === 'action'
    }))
    .borderRadius(TgUiTokens.CHAT_BOTTOM_BAR_RADIUS)
    .clip(true)
    .responseRegion(this.mode === 'action' ? {
      x: 0,
      y: 0,
      width: '100%',
      height: TgUiTokens.CHAT_BOTTOM_BAR_HEIGHT
    } : {
      x: 0,
      y: 0,
      width: 0,
      height: 0
    })
    .accessibilityText(this.mode === 'action' ? this.actionText : this.messageText)
    .onClick(() => {
      if (this.mode === 'action') {
        this.onActionPress();
      }
    })
  }

  @Builder
  private buildFallbackSurface() {
    Row() {
      if (this.mode === 'action') {
        this.buildActionContent()
      } else {
        this.buildRestrictedContent()
      }
    }
    .width('100%')
    .height(TgUiTokens.CHAT_BOTTOM_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.surfaceBg())
    .backdropBlur(this.surfaceBackdropBlur())
    .border({
      width: TgUiTokens.SEARCH_NAV_BORDER_WIDTH,
      color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.CHAT_BOTTOM_BAR_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .responseRegion(this.mode === 'action' ? {
      x: 0,
      y: 0,
      width: '100%',
      height: TgUiTokens.CHAT_BOTTOM_BAR_HEIGHT
    } : {
      x: 0,
      y: 0,
      width: 0,
      height: 0
    })
    .accessibilityText(this.mode === 'action' ? this.actionText : this.messageText)
    .onClick(() => {
      if (this.mode === 'action') {
        this.onActionPress();
      }
    })
  }

  build() {
    Column() {
      if (deviceInfo.apiAvailable('26.0.0')) {
        if (this.useNativeMaterial()) {
          this.buildNativeSurface()
        } else {
          this.buildFallbackSurface()
        }
      } else {
        this.buildFallbackSurface()
      }
    }
    .width('100%')
    .padding({
      left: TgUiTokens.CHAT_BOTTOM_BAR_SIDE_INSET,
      right: TgUiTokens.CHAT_BOTTOM_BAR_SIDE_INSET,
      bottom: this.bottomInset
    })
  }
}
