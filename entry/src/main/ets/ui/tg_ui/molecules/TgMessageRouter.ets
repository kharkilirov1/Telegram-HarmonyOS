// TgMessageRouter — unified bubble container.
// Renders avatar, sender name, reply snippet, content, and meta INSIDE a single bubble.
// Sticker is a special case: no bubble bg, content + meta stacked.
// iOS ref: avatarInset=38pt ALWAYS reserved for incoming group msgs (34 avatar + 4 gap).

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageBubbleBase } from '../atoms/TgMessageBubbleBase';
import { TgPhotoBubble } from '../atoms/TgPhotoBubble';
import { TgGroupedPhotoBubble } from '../atoms/TgGroupedPhotoBubble';
import { TgVideoBubble } from '../atoms/TgVideoBubble';
import { TgDocumentRow } from '../atoms/TgDocumentRow';
import { TgVoiceBubble } from '../atoms/TgVoiceBubble';
import { TgStickerView } from '../atoms/TgStickerView';
import { TgMessageMeta, TgMessageSendStatus } from '../atoms/TgMessageMeta';
import { TgReplySnippet } from '../atoms/TgReplySnippet';

@ComponentV2
export struct TgMessageRouter {
  // ── Routing ──
  @Param contentType: string = 'text';

  // ── Common ──
  @Param messageId: string = '0';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;

  // ── Text / fallback ──
  @Param text: string = '';
  @Param isEmojiOnly: boolean = false;
  @Param forceBreakAll: boolean = false;

  // ── Caption (photo, video) ──
  @Param caption: string = '';

  // ── Photo ──
  @Param photoPath: string = '';
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;
  @Param albumPhotoPaths: string[] = [];
  @Param albumPhotoWidths: number[] = [];
  @Param albumPhotoHeights: number[] = [];

  // ── Video / Animation ──
  @Param videoThumbPath: string = '';
  @Param videoPath: string = '';
  @Param videoDuration: number = 0;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;

  // ── Document / Audio ──
  @Param documentPath: string = '';
  @Param documentFileId: number = 0;
  @Param audioPath: string = '';
  @Param audioFileId: number = 0;
  @Param fileName: string = '';
  @Param fileSize: number = 0;
  @Param mimeType: string = '';

  // ── On-demand download ──
  @Event onMediaDownloadRequest: (fileId: number) => void = (_: number) => {};

  // ── Media viewer callbacks ──
  @Event onPhotoTap: () => void = () => {};
  @Event onAlbumPhotoTap: (photoPath: string, caption: string) => void = (_: string, __: string) => {};
  @Event onVideoTap: () => void = () => {};

  // ── Voice ──
  @Param voicePath: string = '';
  @Param voiceFileId: number = 0;
  @Param voiceDuration: number = 0;
  @Param voiceWaveform: string = '';
  @Param isVoiceListened: boolean = false;
  @Param isVoicePlaying: boolean = false;
  @Param voicePlaybackProgress: number = 0;
  @Event onVoiceTap: (messageId: string, voicePath: string, voiceFileId: number) => void =
    (_: string, __: string, ___: number) => {};

  // ── Sticker ──
  @Param stickerPath: string = '';
  @Param stickerWidth: number = 0;
  @Param stickerHeight: number = 0;
  @Param isAnimatedSticker: boolean = false;
  @Param isVideoSticker: boolean = false;

  // ── Sender name (group chats) ──
  @Param showSenderName: boolean = false;
  @Param senderName: string = '';
  @Param senderColorHex: string = '';

  // ── Avatar (group chats, incoming) ──
  @Param reserveAvatarLane: boolean = false;
  @Param showAvatar: boolean = false;
  @Param avatarImageSrc: string = '';
  @Param avatarInitials: string = '';
  @Param avatarColorIndex: number = 0;

  // ── Reply snippet ──
  @Param showReplySnippet: boolean = false;
  @Param replyAuthor: string = '';
  @Param replyPreview: string = '';
  @Param replyIsOutgoing: boolean = false;
  @Param replyIsQuote: boolean = false;

  // ── Meta (time + send status) ──
  @Param timeText: string = '';
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;

  private isSticker(): boolean {
    return this.contentType === 'sticker';
  }

  private isTextLike(): boolean {
    const ct = this.contentType;
    return ct === 'text'
      || ct === 'unknown'
      || ct === 'unsupported'
      || ct === 'location'
      || ct === 'contact'
      || ct === 'poll'
      || ct.length === 0;
  }

  private isVisualMedia(): boolean {
    const ct = this.contentType;
    return ct === 'photo' || ct === 'photoAlbum' || ct === 'video' || ct === 'animation' || ct === 'videoNote';
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private bubbleRadius(): number {
    return this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING;
  }

  private captionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING;
  }

  private hasCaption(): boolean {
    return this.caption.trim().length > 0;
  }

  // iOS keeps avatar lane reserved by message-group context, not by image hydration state.
  private needsAvatarLane(): boolean {
    return !this.isOutgoing && this.reserveAvatarLane;
  }

  private effectiveAvatarInitials(): string {
    if (this.avatarInitials.trim().length > 0) {
      return this.avatarInitials.trim();
    }
    const sender = this.senderName.trim();
    if (sender.length === 0) {
      return '';
    }
    const parts = sender.split(' ').filter((part: string) => part.length > 0);
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return sender.charAt(0).toUpperCase();
  }

  private avatarInset(): number {
    if (!this.needsAvatarLane()) return 0;
    return TgUiTokens.MSG_AVATAR_SIZE + TgUiTokens.MSG_AVATAR_GAP;
  }

  private maxBubbleWidth(): number {
    const effectiveContainer = this.containerWidth - this.avatarInset();
    return TgUiTokens.resolveBubbleMaxWidth(effectiveContainer, TgUiTokens.BUBBLE_MAX_WIDTH_RATIO);
  }

  private usesRegularBubbleLayout(): boolean {
    return TgUiTokens.isRegularMessageWidth(this.containerWidth - this.avatarInset());
  }

  private photoVisualBubbleWidth(): number {
    const maxAllowed = this.usesRegularBubbleLayout()
      ? TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH_REGULAR
      : TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH;
    const bubbleWidth = Math.max(1, Math.min(this.maxBubbleWidth(), maxAllowed));

    if (this.photoWidth > 0 && this.photoHeight > 0) {
      const maxMediaWidth = Math.max(1, bubbleWidth - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
      const maxMediaHeight = this.usesRegularBubbleLayout()
        ? TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT_REGULAR
        : TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT;
      let scale = Math.min(maxMediaWidth / this.photoWidth, maxMediaHeight / this.photoHeight);
      if (!isFinite(scale) || scale <= 0) {
        scale = 1;
      }

      let fittedWidth = Math.max(1, Math.floor(this.photoWidth * scale));
      const minMediaWidth = Math.max(1, TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
      if (fittedWidth < minMediaWidth) {
        const expandedHeight = Math.max(1, Math.floor(minMediaWidth * this.photoHeight / this.photoWidth));
        if (expandedHeight <= maxMediaHeight) {
          fittedWidth = minMediaWidth;
        }
      }

      return Math.min(maxAllowed, fittedWidth + TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
    }

    return bubbleWidth;
  }

  private visualMediaBubbleWidth(): number {
    const bubbleWidth = this.maxBubbleWidth();
    if (this.contentType === 'photo') {
      return this.photoVisualBubbleWidth();
    }
    if (this.contentType === 'photoAlbum') {
      const maxAllowed = this.usesRegularBubbleLayout()
        ? TgUiTokens.PHOTO_ALBUM_MAX_WIDTH_REGULAR
        : TgUiTokens.PHOTO_ALBUM_MAX_WIDTH;
      const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, bubbleWidth);
      return Math.max(minAllowed, Math.min(bubbleWidth, maxAllowed));
    }
    if (this.contentType === 'video' || this.contentType === 'animation' || this.contentType === 'videoNote') {
      const maxAllowed = this.usesRegularBubbleLayout()
        ? TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH_REGULAR
        : TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH;
      const minAllowed = Math.min(TgUiTokens.VIDEO_BUBBLE_MIN_WIDTH, bubbleWidth);
      return Math.max(minAllowed, Math.min(bubbleWidth, maxAllowed));
    }
    return bubbleWidth;
  }

  private voiceBubbleWidth(): number {
    return TgUiTokens.resolveVoiceBubbleWidth(this.maxBubbleWidth(), 1.0, this.voiceDuration);
  }

  // Build invisible trailing text that reserves space for inline time overlay.
  // The transparent Span at meta font size matches the actual TgMessageMeta width,
  // so text wraps around it naturally (iOS trailingLineWidth / Android timeWidth pattern).
  private buildMetaReserve(): string {
    let reserve = '\u00A0\u00A0'; // leading gap (2 NBSP)
    // Mirror the actual time text width
    if (this.timeText.length > 0) {
      reserve += this.timeText;
    } else {
      reserve += '\u00A0\u00A0\u00A0\u00A0\u00A0'; // fallback ~5 chars
    }
    // Reserve for status icon (checkmarks) on outgoing messages
    if (this.isOutgoing && this.sendStatus !== TgMessageSendStatus.None) {
      reserve += '\u00A0\u00A0\u00A0';
    }
    return reserve;
  }

  // Palette for avatar placeholder backgrounds (matches TgChatRow)
  private static readonly AVATAR_COLORS: string[] = [
    '#c03d33', '#4fad2d', '#d09306', '#168acd',
    '#8544d6', '#cd4073', '#2996ad', '#ce671b'
  ];

  @Builder
  private buildInlineMeta(overlayMode: boolean = false) {
    TgMessageMeta({
      timeText: this.timeText,
      sendStatus: this.sendStatus,
      isOutgoing: this.isOutgoing,
      minWidth: 0,
      reserveTimeSlot: false,
      reserveStatusSlot: false,
      overlayMode: overlayMode
    })
  }

  @Builder
  private buildAvatarSlot() {
    // iOS: always reserve avatar space for incoming group — visible or invisible spacer
    if (this.needsAvatarLane()) {
      Column() {
        if (this.showAvatar) {
          if (this.avatarImageSrc.length > 0) {
            Image(this.avatarImageSrc)
              .width(TgUiTokens.MSG_AVATAR_SIZE)
              .height(TgUiTokens.MSG_AVATAR_SIZE)
              .borderRadius(TgUiTokens.MSG_AVATAR_SIZE / 2)
              .objectFit(ImageFit.Cover)
              .clip(true)
          } else {
            Text(this.effectiveAvatarInitials())
              .fontSize(TgUiTokens.MSG_AVATAR_FONT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width(TgUiTokens.MSG_AVATAR_SIZE)
              .height(TgUiTokens.MSG_AVATAR_SIZE)
              .borderRadius(TgUiTokens.MSG_AVATAR_SIZE / 2)
              .backgroundColor(TgMessageRouter.AVATAR_COLORS[this.avatarColorIndex % 8])
          }
        }
      }
      .width(TgUiTokens.MSG_AVATAR_SIZE)
      .margin({ right: TgUiTokens.MSG_AVATAR_GAP })
    }
  }

  @Builder
  private buildMediaContent() {
    // Pass maxBubbleWidth as container so media atoms size correctly within bubble
    if (this.contentType === 'photo') {
      TgPhotoBubble({
        photoPath: this.photoPath,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        photoWidth: this.photoWidth,
        photoHeight: this.photoHeight,
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        useRegularMaxDimensions: this.usesRegularBubbleLayout(),
        onPhotoTap: () => { this.onPhotoTap(); }
      })
    } else if (this.contentType === 'photoAlbum') {
      TgGroupedPhotoBubble({
        photoPaths: this.albumPhotoPaths,
        photoWidths: this.albumPhotoWidths,
        photoHeights: this.albumPhotoHeights,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        onPhotoTap: (photoPath: string) => {
          this.onAlbumPhotoTap(photoPath, this.caption);
        }
      })
    } else if (this.contentType === 'video' || this.contentType === 'animation' || this.contentType === 'videoNote') {
      TgVideoBubble({
        thumbnailPath: this.videoThumbPath,
        videoPath: this.videoPath,
        durationSec: this.videoDuration,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        videoWidth: this.videoWidth,
        videoHeight: this.videoHeight,
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        hidePlayButton: this.contentType === 'animation',
        useRegularMaxDimensions: this.usesRegularBubbleLayout(),
        onVideoPlayTap: () => { this.onVideoTap(); }
      })
    } else if (this.contentType === 'document') {
      TgDocumentRow({
        fileName: this.fileName,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        documentPath: this.documentPath,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        onTap: () => {
          if (this.documentPath.length === 0 && this.documentFileId > 0) {
            this.onMediaDownloadRequest(this.documentFileId);
          }
        }
      })
    } else if (this.contentType === 'audio') {
      TgDocumentRow({
        fileName: this.fileName.length > 0 ? this.fileName : this.caption,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        documentPath: this.audioPath,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        onTap: () => {
          if (this.audioPath.length === 0 && this.audioFileId > 0) {
            this.onMediaDownloadRequest(this.audioFileId);
          }
        }
      })
    } else if (this.contentType === 'voice') {
      TgVoiceBubble({
        durationSec: this.voiceDuration,
        waveform: this.voiceWaveform,
        isOutgoing: this.isOutgoing,
        isPlaying: this.isVoicePlaying,
        playbackProgress: this.voicePlaybackProgress,
        isListened: this.isVoiceListened,
        hasLocalFile: this.voicePath.length > 0,
        containerWidth: this.maxBubbleWidth(),
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        onTap: () => {
          this.onVoiceTap(this.messageId, this.voicePath, this.voiceFileId);
        }
      })
    }
  }

  build() {
    if (this.isSticker()) {
      // ── Sticker: no bubble background ──
      Row() {
        this.buildAvatarSlot()

        Column() {
          if (this.showSenderName && this.senderName.length > 0) {
            Text(this.senderName)
              .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
              .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
              .fontColor(this.senderColorHex)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .margin({ bottom: TgUiTokens.SPACE_2 })
          }

          TgStickerView({
            stickerPath: this.stickerPath,
            isOutgoing: this.isOutgoing,
            isAnimatedSticker: this.isAnimatedSticker,
            isVideoSticker: this.isVideoSticker,
            stickerWidth: this.stickerWidth,
            stickerHeight: this.stickerHeight,
            containerWidth: this.containerWidth
          })

          Row() {
            this.buildInlineMeta()
          }
          .justifyContent(FlexAlign.End)
          .width('100%')
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.isTextLike()) {
      // ── Text bubble: Stack for shrink-wrap + meta overlay at BottomEnd ──
      Row() {
        this.buildAvatarSlot()

        Stack({ alignContent: Alignment.BottomEnd }) {
          Column() {
            if (this.showSenderName && this.senderName.length > 0) {
              Text(this.senderName)
                .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
                .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
                .fontColor(this.senderColorHex)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Start)
                .margin({ bottom: TgUiTokens.SPACE_2 })
            }

            if (this.showReplySnippet) {
              TgReplySnippet({
                author: this.replyAuthor,
                preview: this.replyPreview,
                isOutgoing: this.replyIsOutgoing,
                isQuote: this.replyIsQuote,
                containerWidth: this.maxBubbleWidth()
              })
                .margin({ bottom: TgUiTokens.SPACE_2 })
            }

            TgMessageBubbleBase({
              text: this.text,
              isOutgoing: this.isOutgoing,
              isEmojiOnly: this.isEmojiOnly,
              forceBreakAll: this.forceBreakAll,
              containerWidth: this.maxBubbleWidth(),
              noBubbleWrap: true,
              metaReserveText: this.buildMetaReserve()
            })
          }
          .alignItems(HorizontalAlign.Start)
          .padding({
            left: TgUiTokens.BUBBLE_PADDING_H,
            right: TgUiTokens.BUBBLE_PADDING_H,
            top: TgUiTokens.BUBBLE_PADDING_V,
            bottom: TgUiTokens.BUBBLE_PADDING_V
          })

          Row() {
            this.buildInlineMeta()
          }
          .margin({
            right: TgUiTokens.BUBBLE_PADDING_H,
            bottom: TgUiTokens.BUBBLE_PADDING_V
          })
        }
        .constraintSize({ maxWidth: this.maxBubbleWidth() })
        .backgroundColor(this.bubbleColor())
        .borderRadius(this.bubbleRadius())
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else {
      // ── Media bubble (photo, video, document, voice) ──
      Row() {
        this.buildAvatarSlot()

        Column() {
          if (this.showSenderName && this.senderName.length > 0) {
            Text(this.senderName)
              .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
              .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
              .fontColor(this.senderColorHex)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: this.maxBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2 })
              .textAlign(TextAlign.Start)
              .padding({
                left: TgUiTokens.BUBBLE_PADDING_H,
                right: TgUiTokens.BUBBLE_PADDING_H,
                top: TgUiTokens.BUBBLE_PADDING_V
              })
          }

          if (this.showReplySnippet) {
            Row() {
              TgReplySnippet({
                author: this.replyAuthor,
                preview: this.replyPreview,
                isOutgoing: this.replyIsOutgoing,
                isQuote: this.replyIsQuote,
                containerWidth: this.maxBubbleWidth()
              })
            }
            .padding({
              left: TgUiTokens.BUBBLE_PADDING_H,
              right: TgUiTokens.BUBBLE_PADDING_H,
              top: TgUiTokens.SPACE_2
            })
          }

          if (this.isVisualMedia() && this.caption.trim().length === 0) {
            // Photo/video/animation WITHOUT caption: meta overlays on media (iOS pattern)
            Stack({ alignContent: Alignment.BottomEnd }) {
              this.buildMediaContent()

              Row() {
                this.buildInlineMeta(true)
              }
              .padding({
                left: TgUiTokens.MSG_MEDIA_META_OVERLAY_PADDING_H,
                right: TgUiTokens.MSG_MEDIA_META_OVERLAY_PADDING_H,
                top: TgUiTokens.MSG_MEDIA_META_OVERLAY_PADDING_V,
                bottom: TgUiTokens.MSG_MEDIA_META_OVERLAY_PADDING_V
              })
              .backgroundColor(TgUiTokens.MSG_MEDIA_META_OVERLAY_BG)
              .borderRadius(TgUiTokens.MSG_MEDIA_META_OVERLAY_RADIUS)
              .margin({
                right: TgUiTokens.MSG_MEDIA_META_OVERLAY_MARGIN,
                bottom: TgUiTokens.MSG_MEDIA_META_OVERLAY_MARGIN
              })
            }
            .width(this.visualMediaBubbleWidth())
          } else if (this.isVisualMedia()) {
            // Photo/video WITH caption: media + caption with inline meta (iOS pattern)
            this.buildMediaContent()

            Stack({ alignContent: Alignment.BottomEnd }) {
              Text() {
                Span(this.caption.trim())
                  .fontSize(TgUiTokens.MSG_TEXT_SIZE)
                  .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
                  .fontColor(this.captionColor())
                Span(this.buildMetaReserve())
                  .fontSize(TgUiTokens.MSG_META_SIZE)
                  .fontColor(Color.Transparent)
              }
              .lineHeight(TgUiTokens.MSG_TEXT_LINE_HEIGHT)
              .textAlign(TextAlign.Start)
              .wordBreak(WordBreak.BREAK_WORD)
              .lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)
              .width('100%')
              .padding({
                left: TgUiTokens.BUBBLE_PADDING_H,
                right: TgUiTokens.BUBBLE_PADDING_H,
                top: TgUiTokens.SPACE_6,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })

              Row() {
                this.buildInlineMeta()
              }
              .margin({
                right: TgUiTokens.BUBBLE_PADDING_H,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })
            }
            .width(this.visualMediaBubbleWidth())
          } else if (this.contentType === 'voice') {
            Column() {
              this.buildMediaContent()

              Row() {
                this.buildInlineMeta()
              }
              .justifyContent(FlexAlign.End)
              .width(Math.max(1, this.voiceBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2))
              .margin({
                left: TgUiTokens.BUBBLE_PADDING_H,
                right: TgUiTokens.BUBBLE_PADDING_H,
                top: TgUiTokens.SPACE_2,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })
            }
            .width(this.voiceBubbleWidth())
          } else {
            // Document/audio: meta in separate row below
            this.buildMediaContent()

            Row() {
              this.buildInlineMeta()
            }
            .justifyContent(FlexAlign.End)
            .width('100%')
            .padding({
              right: TgUiTokens.BUBBLE_PADDING_H,
              bottom: TgUiTokens.BUBBLE_PADDING_V,
              top: TgUiTokens.SPACE_2
            })
          }
        }
        .constraintSize({ maxWidth: this.maxBubbleWidth() })
        .backgroundColor(this.bubbleColor())
        .borderRadius(this.bubbleRadius())
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)
    }
  }
}
