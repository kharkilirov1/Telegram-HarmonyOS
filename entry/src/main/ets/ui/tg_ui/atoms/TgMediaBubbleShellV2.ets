import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgPhotoBubble } from './TgPhotoBubble';
import { TgGroupedPhotoBubble } from './TgGroupedPhotoBubble';
import { TgVideoBubble } from './TgVideoBubble';
import { TgAnimationBubble } from './TgAnimationBubble';
import { TgReplySnippet } from './TgReplySnippet';
import { TgTextBodyV3 } from './TgTextBodyV3';
import { TgMessageMeta, TgMessageSendStatus } from './TgMessageMeta';

@ComponentV2
export struct TgMediaBubbleShellV2 {
  @Param mediaKind: string = 'photo'; // photo | photoAlbum | video | animation
  @Param messageId: string = '0';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param groupingFlags: string = 'none';

  @Param caption: string = '';
  @Param captionQuoteOffsets: number[] = [];
  @Param captionQuoteLengths: number[] = [];
  @Param captionQuoteCollapsedFlags: boolean[] = [];

  @Param photoPath: string = '';
  @Param photoFileId: number = 0;
  @Param hasLocalPhoto: boolean = false;
  @Param isPhotoDownloading: boolean = false;
  @Param photoDownloadProgress: number = -1;
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;
  @Param albumPhotoPaths: string[] = [];
  @Param albumPhotoWidths: number[] = [];
  @Param albumPhotoHeights: number[] = [];

  @Param videoThumbPath: string = '';
  @Param videoPath: string = '';
  @Param videoFileId: number = 0;
  @Param isShortVideo: boolean = false;
  @Param isVideoDownloading: boolean = false;
  @Param videoDownloadProgress: number = -1;
  @Param videoDuration: number = 0;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;

  @Param showSenderName: boolean = false;
  @Param senderName: string = '';
  @Param senderColorHex: string = '';

  @Param showReplySnippet: boolean = false;
  @Param replyAuthor: string = '';
  @Param replyAuthorColorHex: string = '';
  @Param replyPreview: string = '';
  @Param replyIsOutgoing: boolean = false;
  @Param replyIsQuote: boolean = false;
  @Param replyHasThumbnail: boolean = false;
  @Param replyThumbnailSrc: Resource | string = '';

  @Param timeText: string = '';
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;

  @Event onMediaDownloadRequest: (fileId: number) => void = (_: number) => {};
  @Event onPhotoTap: () => void = () => {};
  @Event onAlbumPhotoTap: (photoPath: string, caption: string) => void = (_: string, __: string) => {};
  @Event onMediaGalleryOpen: (messageId: string) => void = (_: string) => {};

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private bubbleRadius(): number | BorderRadiuses {
    const defaultRadius = this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING;
    const smallRadius = TgUiTokens.BUBBLE_RADIUS_GROUPED;

    if (this.groupingFlags === 'none') {
      return defaultRadius;
    }

    if (this.isOutgoing) {
      if (this.groupingFlags === 'middle' || this.groupingFlags === 'both') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: smallRadius, bottomRight: smallRadius };
      }
      if (this.groupingFlags === 'top') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: defaultRadius, bottomRight: smallRadius };
      }
      if (this.groupingFlags === 'bottom') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: smallRadius, bottomRight: defaultRadius };
      }
    } else {
      if (this.groupingFlags === 'middle' || this.groupingFlags === 'both') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: smallRadius, bottomLeft: smallRadius };
      }
      if (this.groupingFlags === 'top') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: defaultRadius, bottomLeft: smallRadius };
      }
      if (this.groupingFlags === 'bottom') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: smallRadius, bottomLeft: defaultRadius };
      }
    }

    return defaultRadius;
  }

  private captionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING;
  }

  private hasCaption(): boolean {
    return this.caption.trim().length > 0;
  }

  private hasCaptionQuoteBlocks(): boolean {
    const count = Math.min(this.captionQuoteOffsets.length, this.captionQuoteLengths.length);
    for (let i = 0; i < count; i++) {
      if (this.captionQuoteLengths[i] > 0) {
        return true;
      }
    }
    return false;
  }

  private usesRegularBubbleLayout(): boolean {
    return TgUiTokens.isRegularMessageWidth(this.containerWidth);
  }

  private maxBubbleWidth(): number {
    return TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
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
    if (this.mediaKind === 'photo') {
      return this.photoVisualBubbleWidth();
    }
    if (this.mediaKind === 'photoAlbum') {
      const maxAllowed = this.usesRegularBubbleLayout()
        ? TgUiTokens.PHOTO_ALBUM_MAX_WIDTH_REGULAR
        : TgUiTokens.PHOTO_ALBUM_MAX_WIDTH;
      const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, bubbleWidth);
      return Math.max(minAllowed, Math.min(bubbleWidth, maxAllowed));
    }
    if (this.mediaKind === 'video' || this.mediaKind === 'animation') {
      const maxAllowed = this.usesRegularBubbleLayout()
        ? TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH_REGULAR
        : TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH;
      const minAllowed = Math.min(TgUiTokens.VIDEO_BUBBLE_MIN_WIDTH, bubbleWidth);
      return Math.max(minAllowed, Math.min(bubbleWidth, maxAllowed));
    }
    return bubbleWidth;
  }

  private buildMetaReserve(): string {
    let reserve = '\u00A0\u00A0';
    if (this.timeText.length > 0) {
      reserve += this.timeText;
    } else {
      reserve += '\u00A0\u00A0\u00A0\u00A0\u00A0';
    }
    if (this.isOutgoing && this.sendStatus !== TgMessageSendStatus.None) {
      reserve += '\u00A0\u00A0\u00A0';
    }
    return reserve;
  }

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
  private buildMediaNode() {
    if (this.mediaKind === 'photo') {
      TgPhotoBubble({
        photoPath: this.photoPath,
        hasLocalPhoto: this.hasLocalPhoto,
        isDownloading: this.isPhotoDownloading,
        downloadProgress: this.photoDownloadProgress,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        photoWidth: this.photoWidth,
        photoHeight: this.photoHeight,
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        useRegularMaxDimensions: this.usesRegularBubbleLayout(),
        onPhotoTap: () => { this.onPhotoTap(); },
        onDownloadToggle: () => {
          if (!this.hasLocalPhoto && !this.isPhotoDownloading && this.photoFileId > 0) {
            this.onMediaDownloadRequest(this.photoFileId);
          }
        }
      })
    } else if (this.mediaKind === 'photoAlbum') {
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
    } else if (this.mediaKind === 'animation') {
      TgAnimationBubble({
        thumbnailPath: this.videoThumbPath,
        animationPath: this.videoPath,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        animationWidth: this.videoWidth,
        animationHeight: this.videoHeight,
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        useRegularMaxDimensions: this.usesRegularBubbleLayout(),
        isDownloadPending: this.isVideoDownloading,
        downloadProgress: this.videoDownloadProgress,
        onAnimationTap: () => { this.onMediaGalleryOpen(this.messageId); },
        onDownloadToggle: () => {
          if (!this.videoPath && !this.isVideoDownloading && this.videoFileId > 0) {
            this.onMediaDownloadRequest(this.videoFileId);
          }
        }
      })
    } else {
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
        isShortVideo: this.isShortVideo,
        useRegularMaxDimensions: this.usesRegularBubbleLayout(),
        isDownloadPending: this.isVideoDownloading,
        downloadProgress: this.videoDownloadProgress,
        onVideoPlayTap: () => { this.onMediaGalleryOpen(this.messageId); },
        onDownloadToggle: () => {
          if (!this.videoPath && !this.isVideoDownloading && this.videoFileId > 0) {
            this.onMediaDownloadRequest(this.videoFileId);
          }
        }
      })
    }
  }

  build() {
    Row() {
      Column() {
        if (this.showSenderName && this.senderName.length > 0) {
          Text(this.senderName)
            .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
            .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
            .fontColor(this.senderColorHex.length > 0 ? this.senderColorHex : TgUiTokens.COLOR_TEXT_TITLE)
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
              accentHex: this.replyAuthorColorHex,
              hasThumbnail: this.replyHasThumbnail,
              thumbnailSrc: this.replyThumbnailSrc,
              containerWidth: this.maxBubbleWidth()
            })
          }
          .padding({
            left: TgUiTokens.BUBBLE_PADDING_H,
            right: TgUiTokens.BUBBLE_PADDING_H,
            top: TgUiTokens.SPACE_2
          })
        }

        if (!this.hasCaption()) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            this.buildMediaNode()

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
        } else {
          this.buildMediaNode()

          if (this.hasCaptionQuoteBlocks()) {
            Stack({ alignContent: Alignment.BottomEnd }) {
              TgTextBodyV3({
                text: this.caption.trim(),
                isOutgoing: this.isOutgoing,
                quoteAccentHex: !this.isOutgoing && this.senderColorHex.length > 0 ? this.senderColorHex : '',
                contentWidth: this.visualMediaBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2,
                quoteOffsets: this.captionQuoteOffsets,
                quoteLengths: this.captionQuoteLengths,
                quoteCollapsedFlags: this.captionQuoteCollapsedFlags,
                textEntities: [],
              })

              Row() {
                this.buildInlineMeta()
              }
              .justifyContent(FlexAlign.End)
              .margin({
                right: TgUiTokens.BUBBLE_PADDING_H,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })
            }
            .width('100%')
              .padding({
                left: TgUiTokens.BUBBLE_PADDING_H,
                right: TgUiTokens.BUBBLE_PADDING_H,
                top: TgUiTokens.SPACE_6,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })
            .width(this.visualMediaBubbleWidth())
          } else {
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
          }
        }
      }
      .constraintSize({ maxWidth: this.maxBubbleWidth() })
      .backgroundColor(this.bubbleColor())
      .borderRadius(this.bubbleRadius())
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
