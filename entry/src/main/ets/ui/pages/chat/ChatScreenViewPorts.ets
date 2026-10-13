// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgPinnedMessageListItem } from '../../tg_ui/atoms/TgPinnedMessageList';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatMessageActionItem } from './ChatMessageActionsController';

export interface ChatMessageActionsPopupPort {
  handleMessageActionPress(item: ChatMessageActionItem): void;
  messageActionItems(forwardState: string): ChatMessageActionItem[];
  messageActionsPopupHeight(forwardState: string): number;
  messageActionsPopupWidth(): number;
}

export interface ChatTimelineRowPort extends ChatMessageActionsPopupPort {
  cancelMediaDownload(fileId: number, messageId?: string ): void;
  effectiveAlbumPhotoDownloadFailed(entry: ChatTimelineEntryVO, downloadRevision: number): boolean[];
  effectiveAlbumPhotoDownloading(entry: ChatTimelineEntryVO, downloadRevision: number): boolean[];
  effectiveVoiceListened(entry: ChatTimelineEntryVO): boolean;
  handleAudioSeek(messageId: string, progress: number): void;
  handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId?: string ): void;
  handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string, messageId?: string ): void;
  handleMediaGalleryOpen(messageId: string): void;
  handleVoiceSeek(messageId: string, progress: number): void;
  handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void;
  isActiveAudioEntry(entry: ChatTimelineEntryVO): boolean;
  isActiveVoiceEntry(entry: ChatTimelineEntryVO): boolean;
  isMediaDownloadFailed(fileId: number, downloadRevision: number): boolean;
  isMediaDownloadPending(fileId: number, downloadRevision: number): boolean;
  jumpToMessageId(messageId: string): void;
  messageActionsPopupStateHandler(messageId: string): (event: PopupStateChangeParam) => void;
  messageActionsPopupWidth(): number;
  openChannelShare(entry: ChatTimelineEntryVO): void;
  requestMediaDownload(fileId: number, messageId?: string ): void;
  showMessageActions(entry: ChatTimelineEntryVO): void;
}

export interface ChatTimelineViewportPort extends ChatTimelineRowPort {
  chatContentStartOffset(): number;
  handleTimelineScrollIndex(start: number, end: number): void;
  handleTimelineTouch(event: TouchEvent): void;
  maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void;
  shouldShowHistoryLoadingPlaceholder(): boolean;
  useSearchFlashOutline(entry: ChatTimelineEntryVO): boolean;
}

export interface ChatKeyboardPanelsPort {
  handleComposerEmojiSelected(emoji: string): void;
  handleComposerGifPress(): void;
  handleComposerStickerModePress(): void;
  handleComposerStickerPress(): void;
  handleCustomEmojiSelected(item: CustomEmojiCellVO): void;
  handleCustomEmojiTabSelected(tabId: string): void;
  handleEmojiSearchQueryChange(query: string): void;
  handleGifSearchQueryChange(query: string): void;
  handleStickerSearchQueryChange(query: string): void;
  handleStickerSelected(cell: StickerCellVO): void;
  handleStickerTabSelected(tabId: string): void;
  loadMoreGifSearch(): void;
  openStickerSettings(): void;
  setEmojiPanelVisible(value: boolean): void;
}

export interface ChatComposerDockPort extends ChatKeyboardPanelsPort {
  botMenuCommandDescriptions(): string[];
  botMenuCommandNames(): string[];
  bottomBarActionLabel(): string;
  bottomBarMessage(): string;
  cancelEditMessage(): void;
  cancelForwardMessages(): void;
  cancelReply(): void;
  clearPendingAttachment(): void;
  removePendingPhoto(uri: string): void;
  movePendingPhoto(uri: string, direction: number): void;
  composerAllows(kind: string): boolean;
  composerAttachmentMenuLabels(): string[];
  composerCanSubmit(): boolean;
  composerKeyboardPanelVisible(): boolean;
  goToNewerSearchResult(): void;
  goToOlderSearchResult(): void;
  handleAttachmentMenuOpenChange(isOpen: boolean): void;
  handleAttachmentRecentPress(item: TgAttachmentRecentItem): void;
  handleBotMenuCommandPress(index: number): void;
  handleBotMenuOpenChange(isOpen: boolean): void;
  handleBotMenuPress(): void;
  handleChatBottomBarAction(): void;
  handleComposerAreaChange(height: number): void;
  handleComposerAttachPress(): void;
  handleComposerAttachmentMenuItemPress(index: number): void;
  handleComposerEmojiPress(): void;
  handleComposerFocusChange(focused: boolean): void;
  handleComposerKeyboardModePress(): void;
  handleComposerSelectionChange(start: number, end: number): void;
  handleComposerTextChange(value: string): void;
  handleComposerVoicePress(): void;
  handleComposerWillFocus(): void;
  handleScrollToBottomPress(): void;
  handleSendMessage(text: string): void;
  handleVoiceRecordCancel(): void;
  handleVoiceRecordLock(): void;
  handleVoiceRecordSend(): void;
  handleVoiceRecordStart(): void;
  retryChatAccess(): void;
}

export interface ChatPinnedOverlayPort {
  chatTopInset(): number;
  handlePinnedListItemPress(index: number): void;
  loadMorePinnedMessages(): void;
  pinnedMessageListItems(): TgPinnedMessageListItem[];
  setPinnedMessagesListVisible(visible: boolean): void;
}

export interface ChatMediaOverlayPort {
  animateMediaGalleryState(isVisible: boolean, sourceMessageId?: string ): void;
  cancelMediaDownload(fileId: number, messageId?: string ): void;
  handleGalleryIndexChange(index: number): void;
  requestMediaDownload(fileId: number, messageId?: string ): void;
}

export interface ChatScreenPagePort {
  chatTopInset(): number;
  closeSearch(): void;
  handleBackPress(): void;
  handleChatViewportAreaChange(newArea: Area): void;
  handlePinnedMessageClose(): void;
  handlePinnedMessageListPress(): void;
  handlePinnedMessagePress(): void;
  handleSearchQueryChange(query: string): void;
  openProfile(): void;
  openSearch(): void;
  pinnedMessageTitle(index: number, totalCount: number): string;
  shouldShowPinnedMessagePanel(): boolean;
}
