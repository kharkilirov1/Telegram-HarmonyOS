// TgMessageRouter — unified bubble container.
// Renders avatar, sender name, reply snippet, content, and meta INSIDE a single bubble.
// Sticker is a special case: no bubble bg, content + meta stacked.
// iOS ref: avatarInset=38pt ALWAYS reserved for incoming group msgs (34 avatar + 4 gap).

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageBubbleBase } from '../atoms/TgMessageBubbleBase';
import { TgPhotoBubble } from '../atoms/TgPhotoBubble';
import { TgGroupedPhotoBubble } from '../atoms/TgGroupedPhotoBubble';
import { TgVideoBubble } from '../atoms/TgVideoBubble';
import { TgInstantVideoBubble } from '../atoms/TgInstantVideoBubble';
import { TgAnimationBubble } from '../atoms/TgAnimationBubble';
import { TgDocumentRow } from '../atoms/TgDocumentRow';
import { TgAudioBubble } from '../atoms/TgAudioBubble';
import { TgVoiceBubble } from '../atoms/TgVoiceBubble';
import { TgStickerView } from '../atoms/TgStickerView';
import { TgMessageMeta, TgMessageSendStatus } from '../atoms/TgMessageMeta';
import { TgReplySnippet } from '../atoms/TgReplySnippet';
import { TgTextBubbleV3 } from '../atoms/TgTextBubbleV3';
import { TgMediaBubbleShellV2 } from '../atoms/TgMediaBubbleShellV2';
import { TgTextLayout } from '../../text_engine/TgTextLayout';
import { computeTextBubbleLayout } from '../layout/TgBubbleLayout';
import { TextBubbleLayout, BubbleLayoutInput } from '../layout/TgBubbleLayoutTypes';
import { TgContactBubble } from '../atoms/TgContactBubble';
import { TgLocationBubble } from '../atoms/TgLocationBubble';
import { TgPollBubble, TgPollOptionVO } from '../atoms/TgPollBubble';
import { TextEntity } from '../../../core/model/AppState';

@ComponentV2
export struct TgMessageRouter {
  // ── Routing ──
  @Param contentType: string = 'text';

  // ── Common ──
  @Param messageId: string = '0';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param groupingFlags: string = 'none'; // none, top, middle/both, bottom

  // ── Text / fallback ──
  @Param text: string = '';
  @Param isEmojiOnly: boolean = false;
  @Param forceBreakAll: boolean = false;
  @Param quoteOffsets: number[] = [];
  @Param quoteLengths: number[] = [];
  @Param quoteCollapsedFlags: boolean[] = [];
  @Param textEntities: TextEntity[] = [];

  // ── Caption (photo, video) ──
  @Param caption: string = '';
  @Param captionQuoteOffsets: number[] = [];
  @Param captionQuoteLengths: number[] = [];
  @Param captionQuoteCollapsedFlags: boolean[] = [];
  @Param captionEntities: TextEntity[] = [];

  // ── Photo ──
  @Param photoPath: string = '';
  @Param photoFileId: number = 0;
  @Param hasLocalPhoto: boolean = false;
  @Param isPhotoDownloading: boolean = false;
  @Param isPhotoDownloadFailed: boolean = false;
  @Param photoDownloadProgress: number = -1;
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;
  @Param albumPhotoPaths: string[] = [];
  @Param albumPhotoWidths: number[] = [];
  @Param albumPhotoHeights: number[] = [];

  // ── Video / Animation ──
  @Param videoThumbPath: string = '';
  @Param videoPath: string = '';
  @Param videoFileId: number = 0;
  @Param isShortVideo: boolean = false;
  @Param isVideoDownloading: boolean = false;
  @Param isVideoDownloadFailed: boolean = false;
  @Param videoDownloadProgress: number = -1;
  @Param videoDuration: number = 0;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;

  // ── Document / Audio ──
  @Param documentPath: string = '';
  @Param documentFileId: number = 0;
  @Param isDocumentDownloading: boolean = false;
  @Param isDocumentDownloadFailed: boolean = false;
  @Param documentDownloadProgress: number = -1;
  @Param audioPath: string = '';
  @Param audioFileId: number = 0;
  @Param isAudioDownloading: boolean = false;
  @Param isAudioDownloadFailed: boolean = false;
  @Param audioDownloadProgress: number = -1;
  @Param audioDuration: number = 0;
  @Param audioTitle: string = '';
  @Param audioPerformer: string = '';
  @Param isAudioPlaying: boolean = false;
  @Param audioPlaybackProgress: number = 0;
  @Param fileName: string = '';
  @Param fileSize: number = 0;
  @Param mimeType: string = '';

  // ── On-demand download ──
  @Event onMediaDownloadRequest: (fileId: number) => void = (_: number) => {};
  @Event onMediaDownloadCancel: (fileId: number) => void = (_: number) => {};

  // ── Media viewer callbacks ──
  @Event onMediaGalleryOpen: (messageId: string) => void = (_: string) => {};
  @Event onPhotoTap: () => void = () => {};
  @Event onAlbumPhotoTap: (photoPath: string, caption: string) => void = (_: string, __: string) => {};
  @Event onVideoTap: () => void = () => {};
  @Event onDocumentTap: (documentPath: string, documentFileId: number, mimeType: string) => void =
    (_: string, __: number, ___: string) => {};
  @Event onAudioTap: (audioPath: string, audioFileId: number, mimeType: string) => void =
    (_: string, __: number, ___: string) => {};

  // ── Voice ──
  @Param voicePath: string = '';
  @Param voiceFileId: number = 0;
  @Param isVoiceDownloading: boolean = false;
  @Param isVoiceDownloadFailed: boolean = false;
  @Param voiceDownloadProgress: number = -1;
  @Param voiceDuration: number = 0;
  @Param voiceWaveform: string = '';
  @Param isVoiceListened: boolean = false;
  @Param isVoicePlaying: boolean = false;
  @Param voicePlaybackProgress: number = 0;
  @Event onVoiceTap: (messageId: string, voicePath: string, voiceFileId: number) => void =
    (_: string, __: string, ___: number) => {};
  @Event onAudioSeek: (messageId: string, progress: number) => void = (_: string, __: number) => {};
  @Event onVoiceSeek: (messageId: string, progress: number) => void = (_: string, __: number) => {};

  // ── Sticker ──
  @Param stickerPath: string = '';
  @Param stickerWidth: number = 0;
  @Param stickerHeight: number = 0;
  @Param isAnimatedSticker: boolean = false;
  @Param isVideoSticker: boolean = false;

  // ── Contact ──
  @Param contactFirstName: string = '';
  @Param contactLastName: string = '';
  @Param contactPhoneNumber: string = '';
  @Param contactUserId: number = 0;

  // ── Location ──
  @Param locationLatitude: number = 0;
  @Param locationLongitude: number = 0;
  @Param locationVenueTitle: string = '';
  @Param locationVenueAddress: string = '';

  // ── Poll ──
  @Param pollQuestion: string = '';
  @Param pollOptions: TgPollOptionVO[] = [];
  @Param pollTotalVoterCount: number = 0;
  @Param pollIsClosed: boolean = false;
  @Param pollIsAnonymous: boolean = true;
  @Param pollType: string = 'regular';

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
  @Param replyAuthorColorHex: string = '';
  @Param replyPreview: string = '';
  @Param replyIsOutgoing: boolean = false;
  @Param replyIsQuote: boolean = false;
  @Param replyHasThumbnail: boolean = false;
  @Param replyThumbnailSrc: Resource | string = '';

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
      || ct.length === 0;
  }

  private isVisualMedia(): boolean {
    const ct = this.contentType;
    return ct === 'photo' || ct === 'photoAlbum' || ct === 'video' || ct === 'animation';
  }

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

  private hasDocumentTransferProgress(): boolean {
    return this.documentDownloadProgress >= 0 && this.documentDownloadProgress < 1;
  }

  private isDocumentTransferActive(): boolean {
    return this.isDocumentDownloading || this.hasDocumentTransferProgress();
  }

  private hasAudioTransferProgress(): boolean {
    return this.audioDownloadProgress >= 0 && this.audioDownloadProgress < 1;
  }

  private isAudioTransferActive(): boolean {
    return this.isAudioDownloading || this.hasAudioTransferProgress();
  }

  private hasVoiceTransferProgress(): boolean {
    return this.voiceDownloadProgress >= 0 && this.voiceDownloadProgress < 1;
  }

  private isVoiceTransferActive(): boolean {
    return this.isVoiceDownloading || this.hasVoiceTransferProgress();
  }

  private computeTextLayout(): TextBubbleLayout | null {
    try {
      const engine = TgTextLayout.getInstance(this.getUIContext())
      const input: BubbleLayoutInput = {
        text: this.text,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth,
        maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
        avatarInset: this.avatarInset(),
        senderName: this.showSenderName ? this.senderName : '',
        replyAuthor: this.showReplySnippet ? this.replyAuthor : '',
        replyPreview: this.showReplySnippet ? this.replyPreview : '',
        replyHasThumbnail: this.showReplySnippet ? this.replyHasThumbnail : false,
        timeText: this.timeText,
        hasStatus: this.isOutgoing && this.sendStatus !== TgMessageSendStatus.None,
        isEmojiOnly: this.isEmojiOnly,
        forceBreakAll: this.forceBreakAll,
        quoteOffsets: this.quoteOffsets,
        quoteLengths: this.quoteLengths,
        quoteCollapsedFlags: this.quoteCollapsedFlags,
      }
      return computeTextBubbleLayout(engine, input)
    } catch (_e) {
      return null // fallback: V3 renders without explicit layout
    }
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
    if (this.contentType === 'videoNote') {
      return TgUiTokens.resolveInstantVideoBubbleSize(this.maxBubbleWidth());
    }
    if (this.contentType === 'video' || this.contentType === 'animation') {
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

  private audioBubbleWidth(): number {
    return TgUiTokens.resolveAudioBubbleWidth(this.maxBubbleWidth(), 1.0);
  }

  private hasVenueInfo(): boolean {
    return this.locationVenueTitle.trim().length > 0 || this.locationVenueAddress.trim().length > 0;
  }

  private stickerMaxSide(): number {
    const byContainer = Math.floor(this.containerWidth * 0.65);
    const maxByType = (this.isAnimatedSticker || this.isVideoSticker)
      ? TgUiTokens.STICKER_VIEW_ANIMATED_MAX_SIZE
      : TgUiTokens.STICKER_VIEW_MAX_SIZE;
    return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.min(byContainer, maxByType));
  }

  private stickerRenderWidth(): number {
    const maxSide = this.stickerMaxSide();
    if (this.stickerWidth > 0 && this.stickerHeight > 0) {
      const ratio = this.stickerWidth / this.stickerHeight;
      if (ratio >= 1) {
        return maxSide;
      }
      return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.floor(maxSide * ratio));
    }
    return maxSide;
  }

  private stickerRenderHeight(): number {
    const maxSide = this.stickerMaxSide();
    if (this.stickerWidth > 0 && this.stickerHeight > 0) {
      const ratio = this.stickerWidth / this.stickerHeight;
      if (ratio >= 1) {
        return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.floor(maxSide / ratio));
      }
      return maxSide;
    }
    return maxSide;
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
  private buildOverlayMetaPill() {
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
        hasLocalPhoto: this.hasLocalPhoto,
        isDownloading: this.isPhotoDownloading,
        isDownloadFailed: this.isPhotoDownloadFailed,
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
          if (this.isPhotoDownloading && this.photoFileId > 0) {
            this.onMediaDownloadCancel(this.photoFileId);
          } else if (!this.hasLocalPhoto && this.photoFileId > 0) {
            this.onMediaDownloadRequest(this.photoFileId);
          }
        }
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
    } else if (this.contentType === 'videoNote') {
      TgInstantVideoBubble({
        thumbnailPath: this.videoThumbPath,
        videoPath: this.videoPath,
        durationSec: this.videoDuration,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        isDownloadPending: this.isVideoDownloading,
        isDownloadFailed: this.isVideoDownloadFailed,
        downloadProgress: this.videoDownloadProgress,
        onTap: () => { this.onVideoTap(); },
        onPlayToggle: () => { this.onVideoTap(); },
        onDownloadToggle: () => {
          if (this.isVideoDownloading && this.videoFileId > 0) {
            this.onMediaDownloadCancel(this.videoFileId);
          } else if (!this.videoPath && this.videoFileId > 0) {
            this.onMediaDownloadRequest(this.videoFileId);
          }
        }
      })
    } else if (this.contentType === 'animation') {
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
        isDownloadFailed: this.isVideoDownloadFailed,
        downloadProgress: this.videoDownloadProgress,
        onAnimationTap: () => { this.onMediaGalleryOpen(this.messageId); },
        onDownloadToggle: () => {
          if (this.isVideoDownloading && this.videoFileId > 0) {
            this.onMediaDownloadCancel(this.videoFileId);
          } else if (!this.videoPath && this.videoFileId > 0) {
            this.onMediaDownloadRequest(this.videoFileId);
          }
        }
      })
    } else if (this.contentType === 'video') {
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
        isDownloadFailed: this.isVideoDownloadFailed,
        downloadProgress: this.videoDownloadProgress,
        onVideoPlayTap: () => { this.onMediaGalleryOpen(this.messageId); },
        onDownloadToggle: () => {
          if (this.isVideoDownloading && this.videoFileId > 0) {
            this.onMediaDownloadCancel(this.videoFileId);
          } else if (!this.videoPath && this.videoFileId > 0) {
            this.onMediaDownloadRequest(this.videoFileId);
          }
        }
      })
    } else if (this.contentType === 'document' && this.mimeType.startsWith('audio/')) {
      TgAudioBubble({
        title: this.fileName,
        performer: '',
        durationSec: 0,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        audioPath: this.documentPath,
        downloadProgress: this.documentDownloadProgress,
        isDownloading: this.isDocumentDownloading,
        isDownloadFailed: this.isDocumentDownloadFailed,
        isOutgoing: this.isOutgoing,
        isPlaying: this.isAudioPlaying,
        playbackProgress: this.audioPlaybackProgress,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        onTap: () => {
          this.onAudioTap(this.documentPath, this.documentFileId, this.mimeType);
        },
        onPlayToggle: () => {
          if (this.isDocumentTransferActive() && this.documentFileId > 0) {
            this.onMediaDownloadCancel(this.documentFileId);
          } else {
            this.onAudioTap(this.documentPath, this.documentFileId, this.mimeType);
          }
        },
        onSeek: (p: number) => {
          this.onAudioSeek(this.messageId, p);
        }
      })
    } else if (this.contentType === 'document') {
      TgDocumentRow({
        fileName: this.fileName,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        documentPath: this.documentPath,
        downloadProgress: this.documentDownloadProgress,
        isDownloading: this.isDocumentDownloading,
        isDownloadFailed: this.isDocumentDownloadFailed,
        isOutgoing: this.isOutgoing,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        onTap: () => {
          this.onDocumentTap(this.documentPath, this.documentFileId, this.mimeType);
        },
        onDownloadToggle: () => {
          if (this.isDocumentTransferActive() && this.documentFileId > 0) {
            this.onMediaDownloadCancel(this.documentFileId);
          } else if (!this.documentPath && this.documentFileId > 0) {
            this.onMediaDownloadRequest(this.documentFileId);
          }
        }
      })
    } else if (this.contentType === 'audio') {
      TgAudioBubble({
        title: this.audioTitle.length > 0 ? this.audioTitle : this.fileName,
        performer: this.audioPerformer,
        durationSec: this.audioDuration,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        audioPath: this.audioPath,
        downloadProgress: this.audioDownloadProgress,
        isDownloading: this.isAudioDownloading,
        isDownloadFailed: this.isAudioDownloadFailed,
        isOutgoing: this.isOutgoing,
        isPlaying: this.isAudioPlaying,
        playbackProgress: this.audioPlaybackProgress,
        containerWidth: this.maxBubbleWidth(),
        noBubbleWrap: true,
        onTap: () => {
          this.onAudioTap(this.audioPath, this.audioFileId, this.mimeType);
        },
        onPlayToggle: () => {
          if (this.isAudioTransferActive() && this.audioFileId > 0) {
            this.onMediaDownloadCancel(this.audioFileId);
          } else {
            this.onAudioTap(this.audioPath, this.audioFileId, this.mimeType);
          }
        },
        onSeek: (p: number) => {
          this.onAudioSeek(this.messageId, p);
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
        isDownloading: this.isVoiceDownloading,
        isDownloadFailed: this.isVoiceDownloadFailed,
        downloadProgress: this.voiceDownloadProgress,
        containerWidth: this.maxBubbleWidth(),
        maxWidthRatio: 1.0,
        noBubbleWrap: true,
        onTap: () => {
          this.onVoiceTap(this.messageId, this.voicePath, this.voiceFileId);
        },
        onPlayToggle: () => {
          if (this.isVoiceTransferActive() && this.voiceFileId > 0) {
            this.onMediaDownloadCancel(this.voiceFileId);
          } else {
            this.onVoiceTap(this.messageId, this.voicePath, this.voiceFileId);
          }
        },
        onSeek: (p: number) => {
          this.onVoiceSeek(this.messageId, p);
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

          Stack({ alignContent: Alignment.BottomEnd }) {
            TgStickerView({
              stickerPath: this.stickerPath,
              isOutgoing: this.isOutgoing,
              isAnimatedSticker: this.isAnimatedSticker,
              isVideoSticker: this.isVideoSticker,
              stickerWidth: this.stickerWidth,
              stickerHeight: this.stickerHeight,
              containerWidth: this.stickerRenderWidth()
            })

            this.buildOverlayMetaPill()
          }
          .width(this.stickerRenderWidth())
          .height(this.stickerRenderHeight())
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.isTextLike()) {
      // ── Text bubble: engine-driven V3 with pre-computed layout ──
      Row() {
        this.buildAvatarSlot()

        TgTextBubbleV3({
          layout: this.computeTextLayout(),
          text: this.text,
          isOutgoing: this.isOutgoing,
          isEmojiOnly: this.isEmojiOnly,
          forceBreakAll: this.forceBreakAll,
          quoteOffsets: this.quoteOffsets,
          quoteLengths: this.quoteLengths,
          quoteCollapsedFlags: this.quoteCollapsedFlags,
          textEntities: this.textEntities,
          quoteAccentHex: this.senderColorHex,
          containerWidth: this.maxBubbleWidth(),
          maxWidthRatio: 1.0,
          groupingFlags: this.groupingFlags,
          showSenderName: this.showSenderName,
          senderName: this.senderName,
          senderColorHex: this.senderColorHex,
          showReplySnippet: this.showReplySnippet,
          replyAuthor: this.replyAuthor,
          replyAuthorColorHex: this.replyAuthorColorHex,
          replyPreview: this.replyPreview,
          replyIsOutgoing: this.replyIsOutgoing,
          replyIsQuote: this.replyIsQuote,
          replyHasThumbnail: this.replyHasThumbnail,
          replyThumbnailSrc: this.replyThumbnailSrc,
          timeText: this.timeText,
          sendStatus: this.sendStatus,
        })
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.contentType === 'videoNote') {
      // ── Instant video bubble: circular media without rectangular wrapper ──
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

          if (this.showReplySnippet) {
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
              .margin({ bottom: TgUiTokens.SPACE_4 })
          }

          if (this.caption.trim().length === 0) {
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
          } else {
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
                top: TgUiTokens.SPACE_6,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })

              Row() {
                this.buildInlineMeta()
              }
              .margin({ right: TgUiTokens.BUBBLE_PADDING_H, bottom: TgUiTokens.BUBBLE_PADDING_V })
            }
            .width(this.visualMediaBubbleWidth())
          }
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.contentType === 'contact') {
      // ── Contact bubble ──
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
              .margin({ bottom: TgUiTokens.SPACE_2 })
          }
          Column() {
            TgContactBubble({
              firstName: this.contactFirstName,
              lastName: this.contactLastName,
              phoneNumber: this.contactPhoneNumber,
              contactUserId: this.contactUserId,
              isOutgoing: this.isOutgoing
            })
            Row() {
              this.buildInlineMeta(false)
            }
            .alignSelf(ItemAlign.End)
            .margin({ top: TgUiTokens.SPACE_2 })
          }
          .constraintSize({ maxWidth: this.maxBubbleWidth() })
          .backgroundColor(this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
          .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)
          .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H, top: TgUiTokens.BUBBLE_PADDING_V, bottom: TgUiTokens.BUBBLE_PADDING_V })
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.contentType === 'location') {
      // ── Location / venue bubble ──
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
              .margin({ bottom: TgUiTokens.SPACE_2 })
          }
          Column() {
            if (!this.hasVenueInfo()) {
              Stack({ alignContent: Alignment.BottomEnd }) {
                TgLocationBubble({
                  latitude: this.locationLatitude,
                  longitude: this.locationLongitude,
                  venueTitle: this.locationVenueTitle,
                  venueAddress: this.locationVenueAddress,
                  isOutgoing: this.isOutgoing
                })

                this.buildOverlayMetaPill()
              }
              .width(this.maxBubbleWidth())
            } else {
              TgLocationBubble({
                latitude: this.locationLatitude,
                longitude: this.locationLongitude,
                venueTitle: this.locationVenueTitle,
                venueAddress: this.locationVenueAddress,
                isOutgoing: this.isOutgoing
              })

              Row() {
                this.buildInlineMeta(false)
              }
              .alignSelf(ItemAlign.End)
              .margin({ top: TgUiTokens.SPACE_2 })
            }
          }
          .constraintSize({ maxWidth: this.maxBubbleWidth() })
          .backgroundColor(this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
          .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)
          .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H, top: TgUiTokens.BUBBLE_PADDING_V, bottom: TgUiTokens.BUBBLE_PADDING_V })
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.contentType === 'poll') {
      // ── Poll bubble ──
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
              .margin({ bottom: TgUiTokens.SPACE_2 })
          }
          Column() {
            TgPollBubble({
              question: this.pollQuestion,
              options: this.pollOptions,
              totalVoterCount: this.pollTotalVoterCount,
              isClosed: this.pollIsClosed,
              isAnonymous: this.pollIsAnonymous,
              pollType: this.pollType,
              isOutgoing: this.isOutgoing
            })
            Row() {
              this.buildInlineMeta(false)
            }
            .alignSelf(ItemAlign.End)
            .margin({ top: TgUiTokens.SPACE_2 })
          }
          .constraintSize({ maxWidth: this.maxBubbleWidth() })
          .backgroundColor(this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
          .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)
          .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H, top: TgUiTokens.BUBBLE_PADDING_V, bottom: TgUiTokens.BUBBLE_PADDING_V })
        }
        .alignItems(this.isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else if (this.isVisualMedia()) {
      // ── Visual media shell: live swap onto the parallel V2 media-family atom ──
      Row() {
        this.buildAvatarSlot()

        TgMediaBubbleShellV2({
          mediaKind: this.contentType,
          messageId: this.messageId,
          isOutgoing: this.isOutgoing,
          containerWidth: this.maxBubbleWidth(),
          maxWidthRatio: 1.0,
          groupingFlags: this.groupingFlags,
          caption: this.caption,
          captionQuoteOffsets: this.captionQuoteOffsets,
          captionQuoteLengths: this.captionQuoteLengths,
          captionQuoteCollapsedFlags: this.captionQuoteCollapsedFlags,
          photoPath: this.photoPath,
          photoFileId: this.photoFileId,
          hasLocalPhoto: this.hasLocalPhoto,
          isPhotoDownloading: this.isPhotoDownloading,
          isPhotoDownloadFailed: this.isPhotoDownloadFailed,
          photoDownloadProgress: this.photoDownloadProgress,
          photoWidth: this.photoWidth,
          photoHeight: this.photoHeight,
          albumPhotoPaths: this.albumPhotoPaths,
          albumPhotoWidths: this.albumPhotoWidths,
          albumPhotoHeights: this.albumPhotoHeights,
          videoThumbPath: this.videoThumbPath,
          videoPath: this.videoPath,
          videoFileId: this.videoFileId,
          isShortVideo: this.isShortVideo,
          isVideoDownloading: this.isVideoDownloading,
          isVideoDownloadFailed: this.isVideoDownloadFailed,
          videoDownloadProgress: this.videoDownloadProgress,
          videoDuration: this.videoDuration,
          videoWidth: this.videoWidth,
          videoHeight: this.videoHeight,
          showSenderName: this.showSenderName,
          senderName: this.senderName,
          senderColorHex: this.senderColorHex,
          showReplySnippet: this.showReplySnippet,
          replyAuthor: this.replyAuthor,
          replyAuthorColorHex: this.replyAuthorColorHex,
          replyPreview: this.replyPreview,
          replyIsOutgoing: this.replyIsOutgoing,
          replyIsQuote: this.replyIsQuote,
          replyHasThumbnail: this.replyHasThumbnail,
          replyThumbnailSrc: this.replyThumbnailSrc,
          timeText: this.timeText,
          sendStatus: this.sendStatus,
          onMediaDownloadRequest: (fileId: number) => {
            this.onMediaDownloadRequest(fileId);
          },
          onPhotoTap: () => {
            this.onPhotoTap();
          },
          onAlbumPhotoTap: (photoPath: string, caption: string) => {
            this.onAlbumPhotoTap(photoPath, caption);
          },
          onMediaGalleryOpen: (messageId: string) => {
            this.onMediaGalleryOpen(messageId);
          }
        })
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

    } else {
      // ── Non-visual media bubble (document, audio, voice) ──
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

          if (this.contentType === 'voice') {
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
          } else if (this.contentType === 'audio' || (this.contentType === 'document' && this.mimeType.startsWith('audio/'))) {
            // Audio/music: meta aligned to audio bubble width
            Column() {
              this.buildMediaContent()

              Row() {
                this.buildInlineMeta()
              }
              .justifyContent(FlexAlign.End)
              .width(Math.max(1, this.audioBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2))
              .margin({
                left: TgUiTokens.BUBBLE_PADDING_H,
                right: TgUiTokens.BUBBLE_PADDING_H,
                top: TgUiTokens.SPACE_2,
                bottom: TgUiTokens.BUBBLE_PADDING_V
              })
            }
            .width(this.audioBubbleWidth())
          } else {
            // Document: meta in separate row below
            this.buildMediaContent()

            Row() {
              this.buildInlineMeta()
            }
            .alignSelf(ItemAlign.End)
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
