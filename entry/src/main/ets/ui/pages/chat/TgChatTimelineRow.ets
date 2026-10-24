// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { composerPopupTransition } from '../../tg_ui/utils/TgComposerMotionPolicy';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { albumMediaSourceId } from '../../tg_ui/utils/TgMediaGeometryTransition';
import { ChatChromeState } from './ChatChromeState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatTimelineRowPort } from './ChatScreenViewPorts';
import { TgChatMessageActionsPopup } from './TgChatMessageActionsPopup';

@ComponentV2
export struct TgChatTimelineRow {
  @Require @Param chrome: ChatChromeState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param bindings: ChatTimelineRowPort;
  @Require @Param entry: ChatTimelineEntryVO;

  build() {
    Column() {
      TgMessageRouter({
        messageId: this.entry.message.messageId,
        hiddenMediaMessageId: this.media.gallerySourceMessageId,
        contentType: this.entry.message.contentType,
        isOutgoing: this.entry.message.isOutgoing,
        containerWidth: this.chrome.timelineContainerWidth,
        isBroadcastChannel: this.chrome.activeChatIsChannel,
        groupingFlags: this.entry.message.groupingFlags,
        text: this.entry.message.text,
        isEmojiOnly: this.entry.message.isEmojiOnly,
        forceBreakAll: this.entry.message.forceBreakAll,
        quoteOffsets: this.entry.message.quoteOffsets,
        quoteLengths: this.entry.message.quoteLengths,
        quoteCollapsedFlags: this.entry.message.quoteCollapsedFlags,
        textEntities: this.entry.message.textEntities,
        linkPreviewUrl: this.entry.message.linkPreviewUrl,
        linkPreviewDisplayUrl: this.entry.message.linkPreviewDisplayUrl,
        linkPreviewSiteName: this.entry.message.linkPreviewSiteName,
        linkPreviewTitle: this.entry.message.linkPreviewTitle,
        linkPreviewDescription: this.entry.message.linkPreviewDescription,
        linkPreviewAuthor: this.entry.message.linkPreviewAuthor,
        linkPreviewPhotoPath: this.entry.message.linkPreviewPhotoPath,
        linkPreviewPhotoMinithumb: this.entry.message.linkPreviewPhotoMinithumb,
        linkPreviewShowLargeMedia: this.entry.message.linkPreviewShowLargeMedia,
        linkPreviewShowMediaAboveDescription: this.entry.message.linkPreviewShowMediaAboveDescription,
        linkPreviewShowAboveText: this.entry.message.linkPreviewShowAboveText,
        caption: this.entry.message.caption,
        captionQuoteOffsets: this.entry.message.captionQuoteOffsets,
        captionQuoteLengths: this.entry.message.captionQuoteLengths,
        captionQuoteCollapsedFlags: this.entry.message.captionQuoteCollapsedFlags,
        captionEntities: this.entry.message.captionEntities,
        photoPath: this.entry.message.photoPath,
        photoFileId: this.entry.message.photoFileId,
        photoMinithumb: this.entry.message.photoMinithumb,
        hasLocalPhoto: this.entry.message.hasLocalPhoto,
        isPhotoDownloading: this.entry.message.isPhotoDownloading || this.bindings.isMediaDownloadPending(this.entry.message.photoFileId, this.media.pendingMediaDownloadVersion),
        isPhotoDownloadFailed: this.bindings.isMediaDownloadFailed(this.entry.message.photoFileId, this.media.pendingMediaDownloadVersion),
        photoDownloadProgress: this.entry.message.photoDownloadProgress,
        photoWidth: this.entry.message.photoWidth,
        photoHeight: this.entry.message.photoHeight,
        albumPhotoPaths: this.entry.message.albumPhotoPaths,
        albumPhotoMinithumbs: this.entry.message.albumPhotoMinithumbs,
        albumPhotoMessageIds: this.entry.message.sourceMessageIds,
        albumPhotoFileIds: this.entry.message.albumPhotoFileIds,
        albumPhotoHasLocal: this.entry.message.albumPhotoHasLocal,
        albumPhotoDownloading: this.bindings.effectiveAlbumPhotoDownloading(this.entry, this.media.pendingMediaDownloadVersion),
        albumPhotoDownloadFailed: this.bindings.effectiveAlbumPhotoDownloadFailed(this.entry, this.media.pendingMediaDownloadVersion),
        albumPhotoDownloadProgress: this.entry.message.albumPhotoDownloadProgress,
        albumPhotoWidths: this.entry.message.albumPhotoWidths,
        albumPhotoHeights: this.entry.message.albumPhotoHeights,
        videoThumbPath: this.entry.message.videoThumbPath,
        videoMinithumb: this.entry.message.videoMinithumb,
        videoPath: this.entry.message.videoPath,
        videoFileId: this.entry.message.videoFileId,
        isVideoDownloading: this.entry.message.isVideoDownloading || this.bindings.isMediaDownloadPending(this.entry.message.videoFileId, this.media.pendingMediaDownloadVersion),
        isVideoDownloadFailed: this.bindings.isMediaDownloadFailed(this.entry.message.videoFileId, this.media.pendingMediaDownloadVersion),
        videoDownloadProgress: this.entry.message.videoDownloadProgress,
        videoDuration: this.entry.message.videoDuration,
        videoWidth: this.entry.message.videoWidth,
        videoHeight: this.entry.message.videoHeight,
        documentPath: this.entry.message.documentPath,
        documentFileId: this.entry.message.documentFileId,
        isDocumentDownloading: this.entry.message.isDocumentDownloading ||
          this.bindings.isMediaDownloadPending(this.entry.message.documentFileId, this.media.pendingMediaDownloadVersion),
        isDocumentDownloadFailed: this.bindings.isMediaDownloadFailed(this.entry.message.documentFileId, this.media.pendingMediaDownloadVersion),
        documentDownloadProgress: this.entry.message.documentDownloadProgress,
        audioPath: this.entry.message.audioPath,
        audioFileId: this.entry.message.audioFileId,
        isAudioDownloading: this.entry.message.isAudioDownloading || this.bindings.isMediaDownloadPending(this.entry.message.audioFileId, this.media.pendingMediaDownloadVersion),
        isAudioDownloadFailed: this.bindings.isMediaDownloadFailed(this.entry.message.audioFileId, this.media.pendingMediaDownloadVersion),
        audioDownloadProgress: this.entry.message.audioDownloadProgress,
        audioDuration: this.entry.message.audioDuration,
        audioTitle: this.entry.message.audioTitle,
        audioPerformer: this.entry.message.audioPerformer,
        fileName: this.entry.message.fileName,
        fileSize: this.entry.message.fileSize,
        mimeType: this.entry.message.mimeType,
        voicePath: this.entry.message.voicePath,
        voiceFileId: this.entry.message.voiceFileId,
        isVoiceDownloading: this.entry.message.isVoiceDownloading || this.bindings.isMediaDownloadPending(this.entry.message.voiceFileId, this.media.pendingMediaDownloadVersion),
        isVoiceDownloadFailed: this.bindings.isMediaDownloadFailed(this.entry.message.voiceFileId, this.media.pendingMediaDownloadVersion),
        voiceDownloadProgress: this.entry.message.voiceDownloadProgress,
        voiceDuration: this.entry.message.voiceDuration,
        voiceWaveform: this.entry.message.voiceWaveform,
        isVoiceListened: this.bindings.effectiveVoiceListened(this.entry),
        isVoicePlaying: this.bindings.isActiveVoiceEntry(this.entry) ? this.media.activeVoicePlaying : false,
        voicePlaybackProgress: this.bindings.isActiveVoiceEntry(this.entry) ? this.media.activeVoiceProgress : 0,
        isAudioPlaying: this.bindings.isActiveAudioEntry(this.entry) ? this.media.activeAudioPlaying : false,
        audioPlaybackProgress: this.bindings.isActiveAudioEntry(this.entry) ? this.media.activeAudioProgress : 0,
        stickerPath: this.entry.message.stickerPath,
        stickerFileId: this.entry.message.stickerFileId,
        stickerThumbnailPath: this.entry.message.stickerThumbnailPath,
        stickerWidth: this.entry.message.stickerWidth,
        stickerHeight: this.entry.message.stickerHeight,
        isAnimatedSticker: this.entry.message.isAnimatedSticker,
        isVideoSticker: this.entry.message.isVideoSticker,
        stickerEmoji: this.entry.message.stickerEmoji,
        contactFirstName: this.entry.message.contactFirstName,
        contactLastName: this.entry.message.contactLastName,
        contactPhoneNumber: this.entry.message.contactPhoneNumber,
        contactUserId: this.entry.message.contactUserId,
        locationLatitude: this.entry.message.locationLatitude,
        locationLongitude: this.entry.message.locationLongitude,
        locationVenueTitle: this.entry.message.locationVenueTitle,
        locationVenueAddress: this.entry.message.locationVenueAddress,
        pollQuestion: this.entry.message.pollQuestion,
        pollOptions: this.entry.message.pollOptions,
        pollTotalVoterCount: this.entry.message.pollTotalVoterCount,
        pollIsClosed: this.entry.message.pollIsClosed,
        pollIsAnonymous: this.entry.message.pollIsAnonymous,
        pollType: this.entry.message.pollType,
        showSenderName: this.entry.message.showSenderName,
        senderName: this.entry.message.senderName,
        senderColorHex: this.entry.message.senderColorHex,
        reserveAvatarLane: this.entry.message.reserveAvatarLane,
        showAvatar: this.entry.message.showAvatar,
        avatarImageSrc: this.entry.message.avatarImageSrc,
        avatarInitials: this.entry.message.avatarInitials,
        avatarColorIndex: this.entry.message.avatarColorIndex,
        showReplySnippet: this.entry.message.showReplySnippet,
        replyAuthor: this.entry.message.replyAuthor,
        replyAuthorColorHex: this.entry.message.replyAuthorColorHex,
        replyPreview: this.entry.message.replyPreview,
        replyIsOutgoing: this.entry.message.replyIsOutgoing,
        replyIsQuote: this.entry.message.replyIsQuote,
        replyHasThumbnail: this.entry.message.replyHasThumbnail,
        replyThumbnailSrc: this.entry.message.replyThumbnailSrc,
        timeText: this.entry.message.timeText,
        editedText: this.entry.message.editedText,
        sendStatus: this.entry.message.sendStatus,
        isShortVideo: this.entry.message.isShortVideo,
        onMediaDownloadRequest: (fileId: number): void => {
          this.bindings.requestMediaDownload(fileId, this.entry.message.messageId);
        },
        onMediaDownloadCancel: (fileId: number): void => {
          this.bindings.cancelMediaDownload(fileId, this.entry.message.messageId);
        },
        onMediaGalleryOpen: (messageId: string): void => {
          this.bindings.handleMediaGalleryOpen(messageId);
        },
        onPhotoTap: (): void => {
          this.bindings.handleMediaGalleryOpen(this.entry.message.messageId);
        },
        onAlbumPhotoTap: (albumIndex: number): void => {
          const memberMessageId = albumIndex >= 0 && albumIndex < this.entry.message.sourceMessageIds.length
            ? this.entry.message.sourceMessageIds[albumIndex] : '';
          const sourceMessageId = albumIndex >= 0 && albumIndex < this.entry.message.albumPhotoPaths.length
            ? albumMediaSourceId(this.entry.message.messageId, memberMessageId, albumIndex)
            : this.entry.message.messageId;
          this.bindings.handleMediaGalleryOpen(sourceMessageId);
        },
        onVideoTap: (): void => {
          this.bindings.handleMediaGalleryOpen(this.entry.message.messageId);
        },
        onDocumentTap: (documentPath: string, documentFileId: number, mimeType: string): void => {
          this.bindings.handleDocumentTap(documentPath, documentFileId, mimeType, this.entry.message.messageId);
        },
        onAudioTap: (audioPath: string, audioFileId: number, mimeType: string): void => {
          this.bindings.handleAudioTap(audioPath, audioFileId, mimeType, this.entry.message.messageId);
        },
        onReplyPress: (): void => {
          if (this.entry.message.replyToMessageId !== '0') {
            this.bindings.jumpToMessageId(this.entry.message.replyToMessageId);
          }
        },
        onChannelSharePress: (): void => {
          this.bindings.openChannelShare(this.entry);
        },
        onVoiceTap: (messageId: string, voicePath: string, voiceFileId: number): void => {
          this.bindings.handleVoiceTap(messageId, voicePath, voiceFileId);
        },
        onAudioSeek: (messageId: string, progress: number): void => {
          this.bindings.handleAudioSeek(messageId, progress);
        },
        onVoiceSeek: (messageId: string, progress: number): void => {
          this.bindings.handleVoiceSeek(messageId, progress);
        }
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_12,
      right: TgUiTokens.SPACE_12,
      top: this.entry.message.topSpacing,
      bottom: 0
    })
    .bindPopup(this.timeline.messageActionsOpenId === this.entry.message.messageId, {
      builder: this.buildMessageActionsPopup,
      placement: Placement.Top,
      popupColor: TgUiTokens.COMPOSER_CAPSULE_BG,
      enableArrow: false,
      autoCancel: true,
      mask: false,
      targetSpace: TgUiTokens.COMPOSER_BOT_POPUP_TARGET_GAP,
      width: this.bindings.messageActionsPopupWidth(),
      radius: TgUiTokens.COMPOSER_CAPSULE_RADIUS,
      shadow: ShadowStyle.OUTER_DEFAULT_MD,
      backgroundBlurStyle: TgGlassPolicy.composerBlurStyle(),
      transition: composerPopupTransition(),
      onStateChange: this.bindings.messageActionsPopupStateHandler(this.entry.message.messageId)
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          this.bindings.showMessageActions(this.entry);
        })
    )
  }

  @Builder
  private buildMessageActionsPopup() {
    TgChatMessageActionsPopup({ timeline: this.timeline, bindings: this.bindings })
  }
}
