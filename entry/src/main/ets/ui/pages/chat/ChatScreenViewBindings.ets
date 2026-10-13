// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgPinnedMessageListItem } from '../../tg_ui/atoms/TgPinnedMessageList';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatMessageActionItem } from './ChatMessageActionsController';
import { ChatScreenSession } from './ChatScreenSession';
import { ChatMessageActionsPopupPort, ChatTimelineRowPort, ChatTimelineViewportPort, ChatKeyboardPanelsPort, ChatComposerDockPort, ChatPinnedOverlayPort, ChatMediaOverlayPort, ChatScreenPagePort } from './ChatScreenViewPorts';

export class ChatScreenViewBindings implements ChatMessageActionsPopupPort, ChatTimelineRowPort, ChatTimelineViewportPort, ChatKeyboardPanelsPort, ChatComposerDockPort, ChatPinnedOverlayPort, ChatMediaOverlayPort, ChatScreenPagePort {
  private session: ChatScreenSession;

  constructor(session: ChatScreenSession) {
    this.session = session;
  }

  get dataSource(): ChatTimelineDataSource { return this.session.dataSource; }
  get listScroller(): Scroller { return this.session.listScroller; }

  animateMediaGalleryState(isVisible: boolean, sourceMessageId?: string ): void { this.session.animateMediaGalleryState(isVisible, sourceMessageId); }
  botMenuCommandDescriptions(): string[] { return this.session.botMenuCommandDescriptions(); }
  botMenuCommandNames(): string[] { return this.session.botMenuCommandNames(); }
  bottomBarActionLabel(): string { return this.session.bottomBarActionLabel(); }
  bottomBarMessage(): string { return this.session.bottomBarMessage(); }
  cancelEditMessage(): void { this.session.cancelEditMessage(); }
  cancelForwardMessages(): void { this.session.cancelForwardMessages(); }
  cancelMediaDownload(fileId: number, messageId?: string ): void { this.session.cancelMediaDownload(fileId, messageId); }
  cancelReply(): void { this.session.cancelReply(); }
  chatContentStartOffset(): number { return this.session.chatContentStartOffset(); }
  chatTopInset(): number { return this.session.chatTopInset(); }
  clearPendingAttachment(): void { this.session.clearPendingAttachment(); }
  removePendingPhoto(uri: string): void { this.session.removePendingPhoto(uri); }
  movePendingPhoto(uri: string, direction: number): void { this.session.movePendingPhoto(uri, direction); }
  closeSearch(): void { this.session.closeSearch(); }
  composerAllows(kind: string): boolean { return this.session.composerAllows(kind); }
  composerAttachmentMenuLabels(): string[] { return this.session.composerAttachmentMenuLabels(); }
  composerCanSubmit(): boolean { return this.session.composerCanSubmit(); }
  composerKeyboardPanelVisible(): boolean { return this.session.composerKeyboardPanelVisible(); }
  effectiveAlbumPhotoDownloadFailed(entry: ChatTimelineEntryVO, downloadRevision: number): boolean[] { return this.session.effectiveAlbumPhotoDownloadFailed(entry); }
  effectiveAlbumPhotoDownloading(entry: ChatTimelineEntryVO, downloadRevision: number): boolean[] { return this.session.effectiveAlbumPhotoDownloading(entry); }
  effectiveVoiceListened(entry: ChatTimelineEntryVO): boolean { return this.session.effectiveVoiceListened(entry); }
  goToNewerSearchResult(): void { this.session.searchCtrl.goToNewerResult(this.session); }
  goToOlderSearchResult(): void { this.session.searchCtrl.goToOlderResult(this.session); }
  handleAttachmentMenuOpenChange(isOpen: boolean): void { this.session.handleAttachmentMenuOpenChange(isOpen); }
  handleAttachmentRecentPress(item: TgAttachmentRecentItem): void { this.session.handleAttachmentRecentPress(item); }
  handleAudioSeek(messageId: string, progress: number): void { this.session.handleAudioSeek(messageId, progress); }
  handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId?: string ): void { this.session.handleAudioTap(audioPath, audioFileId, mimeType, messageId); }
  handleBackPress(): void { this.session.handleBackPress(); }
  handleBotMenuCommandPress(index: number): void { this.session.handleBotMenuCommandPress(index); }
  handleBotMenuOpenChange(isOpen: boolean): void { this.session.handleBotMenuOpenChange(isOpen); }
  handleBotMenuPress(): void { this.session.handleBotMenuPress(); }
  handleChatBottomBarAction(): void { this.session.handleChatBottomBarAction(); }
  handleChatViewportAreaChange(newArea: Area): void { this.session.handleChatViewportAreaChange(newArea); }
  handleComposerAreaChange(height: number): void { this.session.handleComposerAreaChange(height); }
  handleComposerAttachPress(): void { this.session.handleComposerAttachPress(); }
  handleComposerAttachmentMenuItemPress(index: number): void { this.session.handleComposerAttachmentMenuItemPress(index); }
  handleComposerEmojiPress(): void { this.session.handleComposerEmojiPress(); }
  handleComposerEmojiSelected(emoji: string): void { this.session.handleComposerEmojiSelected(emoji); }
  handleComposerFocusChange(focused: boolean): void { this.session.handleComposerFocusChange(focused); }
  handleComposerGifPress(): void { this.session.handleComposerGifPress(); }
  handleComposerKeyboardModePress(): void { this.session.handleComposerKeyboardModePress(); }
  handleComposerSelectionChange(start: number, end: number): void { this.session.handleComposerSelectionChange(start, end); }
  handleComposerStickerModePress(): void { this.session.handleComposerStickerModePress(); }
  handleComposerStickerPress(): void { this.session.handleComposerStickerPress(); }
  handleComposerTextChange(value: string): void { this.session.handleComposerTextChange(value); }
  handleComposerVoicePress(): void { this.session.handleComposerVoicePress(); }
  handleComposerWillFocus(): void { this.session.handleComposerWillFocus(); }
  handleCustomEmojiSelected(item: CustomEmojiCellVO): void { this.session.handleCustomEmojiSelected(item); }
  handleCustomEmojiTabSelected(tabId: string): void { this.session.handleCustomEmojiTabSelected(tabId); }
  handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string, messageId?: string ): void { this.session.handleDocumentTap(documentPath, documentFileId, mimeType, messageId); }
  handleEmojiSearchQueryChange(query: string): void { this.session.handleEmojiSearchQueryChange(query); }
  handleGalleryIndexChange(index: number): void { this.session.handleGalleryIndexChange(index); }
  handleGifSearchQueryChange(query: string): void { this.session.handleGifSearchQueryChange(query); }
  handleMediaGalleryOpen(messageId: string): void { this.session.handleMediaGalleryOpen(messageId); }
  handleMessageActionPress(item: ChatMessageActionItem): void { this.session.handleMessageActionPress(item); }
  handlePinnedListItemPress(index: number): void { this.session.handlePinnedListItemPress(index); }
  handlePinnedMessageClose(): void { this.session.handlePinnedMessageClose(); }
  handlePinnedMessageListPress(): void { this.session.handlePinnedMessageListPress(); }
  handlePinnedMessagePress(): void { this.session.handlePinnedMessagePress(); }
  handleScrollToBottomPress(): void { this.session.handleScrollToBottomPress(); }
  handleSearchQueryChange(query: string): void { this.session.handleSearchQueryChange(query); }
  handleSendMessage(text: string): void { this.session.handleSendMessage(text); }
  handleStickerSearchQueryChange(query: string): void { this.session.handleStickerSearchQueryChange(query); }
  handleStickerSelected(cell: StickerCellVO): void { this.session.handleStickerSelected(cell); }
  handleStickerTabSelected(tabId: string): void { this.session.handleStickerTabSelected(tabId); }
  handleTimelineScrollIndex(start: number, end: number): void { this.session.handleTimelineScrollIndex(start, end); }
  handleTimelineTouch(event: TouchEvent): void { this.session.handleTimelineTouch(event); }
  handleVoiceRecordCancel(): void { this.session.handleVoiceRecordCancel(); }
  handleVoiceRecordLock(): void { this.session.handleVoiceRecordLock(); }
  handleVoiceRecordSend(): void { this.session.handleVoiceRecordSend(); }
  handleVoiceRecordStart(): void { this.session.handleVoiceRecordStart(); }
  handleVoiceSeek(messageId: string, progress: number): void { this.session.handleVoiceSeek(messageId, progress); }
  handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void { this.session.handleVoiceTap(messageId, voicePath, voiceFileId); }
  isActiveAudioEntry(entry: ChatTimelineEntryVO): boolean { return this.session.isActiveAudioEntry(entry); }
  isActiveVoiceEntry(entry: ChatTimelineEntryVO): boolean { return this.session.isActiveVoiceEntry(entry); }
  isMediaDownloadFailed(fileId: number, downloadRevision: number): boolean { return this.session.isMediaDownloadFailed(fileId); }
  isMediaDownloadPending(fileId: number, downloadRevision: number): boolean { return this.session.isMediaDownloadPending(fileId); }
  jumpToMessageId(messageId: string): void { this.session.jumpToMessageId(messageId); }
  loadMoreGifSearch(): void { this.session.loadMoreGifSearch(); }
  loadMorePinnedMessages(): void { this.session.loadMorePinnedMessages(); }
  maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void { this.session.maybeUnlockAutoPagination(scrollOffset, scrollState); }
  messageActionItems(forwardState: string): ChatMessageActionItem[] { return this.session.messageActionItems(); }
  messageActionsPopupHeight(forwardState: string): number { return this.session.messageActionsPopupHeight(); }
  messageActionsPopupStateHandler(messageId: string): (event: PopupStateChangeParam) => void { return this.session.messageActionsPopupStateHandler(messageId); }
  messageActionsPopupWidth(): number { return this.session.messageActionsPopupWidth(); }
  openChannelShare(entry: ChatTimelineEntryVO): void { this.session.messageActionsCtrl.openForwardTargetPickerForEntry(entry, this.session); }
  openProfile(): void { this.session.openProfile(); }
  openSearch(): void { this.session.openSearch(); }
  openStickerSettings(): void { this.session.openStickerSettings(); }
  pinnedMessageListItems(): TgPinnedMessageListItem[] { return this.session.pinnedMessageListItems(); }
  pinnedMessageTitle(index: number, totalCount: number): string { return this.session.pinnedMessageTitle(index, totalCount); }
  requestMediaDownload(fileId: number, messageId?: string ): void { this.session.requestMediaDownload(fileId, messageId); }
  retryChatAccess(): void { this.session.retryChatAccess(); }
  setEmojiPanelVisible(value: boolean): void { this.session.setEmojiPanelVisible(value); }
  setPinnedMessagesListVisible(visible: boolean): void { this.session.setPinnedMessagesListVisible(visible); }
  shouldShowHistoryLoadingPlaceholder(): boolean { return this.session.shouldShowHistoryLoadingPlaceholder(); }
  shouldShowPinnedMessagePanel(): boolean { return this.session.shouldShowPinnedMessagePanel(); }
  showMessageActions(entry: ChatTimelineEntryVO): void { this.session.showMessageActions(entry); }
  useSearchFlashOutline(entry: ChatTimelineEntryVO): boolean { return this.session.useSearchFlashOutline(entry); }
}
