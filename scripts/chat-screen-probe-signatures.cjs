// Probe syntax/order metadata only; no implementation or state snapshots.
module.exports = [
  {
    "name": "getActiveChatId",
    "signature": "getActiveChatId(): number",
    "arguments": []
  },
  {
    "name": "getLifecycleToken",
    "signature": "getLifecycleToken(): number",
    "arguments": []
  },
  {
    "name": "getChatUIContext",
    "signature": "getChatUIContext(): UIContext",
    "arguments": []
  },
  {
    "name": "getSendUseCase",
    "signature": "getSendUseCase(): SendMessageUseCase | undefined",
    "arguments": []
  },
  {
    "name": "getSendMediaUseCase",
    "signature": "getSendMediaUseCase(mediaKind: string = ''): SendMediaMessageUseCase | undefined",
    "arguments": [
      "mediaKind"
    ]
  },
  {
    "name": "setVoiceRecordingState",
    "signature": "setVoiceRecordingState(state: TgVoiceRecordingState, durationMs: number): void",
    "arguments": [
      "state",
      "durationMs"
    ]
  },
  {
    "name": "getEditUseCase",
    "signature": "getEditUseCase(): EditMessageUseCase | undefined",
    "arguments": []
  },
  {
    "name": "getDeleteUseCase",
    "signature": "getDeleteUseCase(): DeleteMessagesUseCase | undefined",
    "arguments": []
  },
  {
    "name": "getSourceForwardUseCase",
    "signature": "getSourceForwardUseCase(): ForwardMessagesUseCase | undefined",
    "arguments": []
  },
  {
    "name": "getForwardUseCase",
    "signature": "getForwardUseCase(sourceChatId: number = this.forwardSourceChatId,\n    messageIds: string[] = this.forwardingMessageIds): ForwardMessagesUseCase | undefined",
    "arguments": [
      "sourceChatId",
      "messageIds"
    ]
  },
  {
    "name": "getPinUseCase",
    "signature": "getPinUseCase(): PinChatMessageUseCase | undefined",
    "arguments": []
  },
  {
    "name": "onPinnedMessageChanged",
    "signature": "onPinnedMessageChanged(): void",
    "arguments": []
  },
  {
    "name": "getSearchUseCase",
    "signature": "getSearchUseCase(): SearchChatMessagesUseCase | undefined",
    "arguments": []
  },
  {
    "name": "isSendingMessage",
    "signature": "isSendingMessage(): boolean",
    "arguments": []
  },
  {
    "name": "setSendingMessage",
    "signature": "setSendingMessage(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "getSendOperationToken",
    "signature": "getSendOperationToken(): number",
    "arguments": []
  },
  {
    "name": "hasActiveChatState",
    "signature": "hasActiveChatState(): boolean",
    "arguments": []
  },
  {
    "name": "isEditModeActive",
    "signature": "isEditModeActive(): boolean",
    "arguments": []
  },
  {
    "name": "isForwardModeActive",
    "signature": "isForwardModeActive(): boolean",
    "arguments": []
  },
  {
    "name": "submitEditMessage",
    "signature": "submitEditMessage(text: string): void",
    "arguments": [
      "text"
    ]
  },
  {
    "name": "submitForwardMessages",
    "signature": "submitForwardMessages(commentText: string): void",
    "arguments": [
      "commentText"
    ]
  },
  {
    "name": "getDraftText",
    "signature": "getDraftText(): string",
    "arguments": []
  },
  {
    "name": "setDraftText",
    "signature": "setDraftText(value: string): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "getDraftSelectionStart",
    "signature": "getDraftSelectionStart(): number",
    "arguments": []
  },
  {
    "name": "getDraftSelectionEnd",
    "signature": "getDraftSelectionEnd(): number",
    "arguments": []
  },
  {
    "name": "setDraftSelection",
    "signature": "setDraftSelection(start: number, end: number): void",
    "arguments": [
      "start",
      "end"
    ]
  },
  {
    "name": "getCustomEmojiEntities",
    "signature": "getCustomEmojiEntities(): CustomEmojiTextEntity[]",
    "arguments": []
  },
  {
    "name": "setCustomEmojiEntities",
    "signature": "setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "setEmojiPanelVisible",
    "signature": "setEmojiPanelVisible(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "getEmojiPanelVisible",
    "signature": "getEmojiPanelVisible(): boolean",
    "arguments": []
  },
  {
    "name": "setStickerPanelVisible",
    "signature": "private setStickerPanelVisible(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "openStickerSettings",
    "signature": "private openStickerSettings(): void",
    "arguments": []
  },
  {
    "name": "getReplyToMessageId",
    "signature": "getReplyToMessageId(): string",
    "arguments": []
  },
  {
    "name": "setReplyMode",
    "signature": "setReplyMode(messageId: string, author: string, preview: string, isQuote: boolean): void",
    "arguments": [
      "messageId",
      "author",
      "preview",
      "isQuote"
    ]
  },
  {
    "name": "clearReplyMode",
    "signature": "clearReplyMode(): void",
    "arguments": []
  },
  {
    "name": "getPendingAttachmentUris",
    "signature": "getPendingAttachmentUris(): string[]",
    "arguments": []
  },
  {
    "name": "getPendingAttachmentKind",
    "signature": "getPendingAttachmentKind(): string",
    "arguments": []
  },
  {
    "name": "setPendingAttachmentState",
    "signature": "setPendingAttachmentState(kind: string, title: string, preview: string, uris: string[]): void",
    "arguments": [
      "kind",
      "title",
      "preview",
      "uris"
    ]
  },
  {
    "name": "clearPendingAttachmentState",
    "signature": "clearPendingAttachmentState(): void",
    "arguments": []
  },
  {
    "name": "scrollToBottomSoon",
    "signature": "scrollToBottomSoon(): void",
    "arguments": []
  },
  {
    "name": "scrollTimelineToBottomAligned",
    "signature": "private scrollTimelineToBottomAligned(): void",
    "arguments": []
  },
  {
    "name": "shouldKeepTimelineBottomAligned",
    "signature": "private shouldKeepTimelineBottomAligned(): boolean",
    "arguments": []
  },
  {
    "name": "scheduleComposerBottomAlignment",
    "signature": "private scheduleComposerBottomAlignment(): void",
    "arguments": []
  },
  {
    "name": "handleComposerFocusChange",
    "signature": "private handleComposerFocusChange(focused: boolean): void",
    "arguments": [
      "focused"
    ]
  },
  {
    "name": "handleComposerWillFocus",
    "signature": "private handleComposerWillFocus(): void",
    "arguments": []
  },
  {
    "name": "handleChatViewportAreaChange",
    "signature": "private handleChatViewportAreaChange(newArea: Area): void",
    "arguments": [
      "newArea"
    ]
  },
  {
    "name": "setEditMode",
    "signature": "setEditMode(messageId: string, originalText: string, allowEmptyEdit: boolean = false): void",
    "arguments": [
      "messageId",
      "originalText",
      "allowEmptyEdit"
    ]
  },
  {
    "name": "getEditingMessageId",
    "signature": "getEditingMessageId(): string",
    "arguments": []
  },
  {
    "name": "getEditingOriginalText",
    "signature": "getEditingOriginalText(): string",
    "arguments": []
  },
  {
    "name": "rebaseEditingMessage",
    "signature": "rebaseEditingMessage(messageId: string, text: string): void",
    "arguments": [
      "messageId",
      "text"
    ]
  },
  {
    "name": "clearEditMode",
    "signature": "clearEditMode(clearDraft: boolean): void",
    "arguments": [
      "clearDraft"
    ]
  },
  {
    "name": "refreshChatInputPanel",
    "signature": "private refreshChatInputPanel(): void",
    "arguments": []
  },
  {
    "name": "canUseComposer",
    "signature": "private canUseComposer(isEditing: boolean, sendKind: string = ''): boolean",
    "arguments": [
      "isEditing",
      "sendKind"
    ]
  },
  {
    "name": "canSendNewMessages",
    "signature": "private canSendNewMessages(sendKind: string = ''): boolean",
    "arguments": [
      "sendKind"
    ]
  },
  {
    "name": "composerCanSubmit",
    "signature": "private composerCanSubmit(): boolean",
    "arguments": []
  },
  {
    "name": "composerAllows",
    "signature": "private composerAllows(kind: string): boolean",
    "arguments": [
      "kind"
    ]
  },
  {
    "name": "setForwardMode",
    "signature": "setForwardMode(messageIds: string[], sourceChatId: number, title: string, preview: string): void",
    "arguments": [
      "messageIds",
      "sourceChatId",
      "title",
      "preview"
    ]
  },
  {
    "name": "getForwardModeState",
    "signature": "getForwardModeState(): ChatForwardModeState",
    "arguments": []
  },
  {
    "name": "clearForwardMode",
    "signature": "clearForwardMode(): void",
    "arguments": []
  },
  {
    "name": "isSearchModeActive",
    "signature": "isSearchModeActive(): boolean",
    "arguments": []
  },
  {
    "name": "getSearchQuery",
    "signature": "getSearchQuery(): string",
    "arguments": []
  },
  {
    "name": "setSearchQuery",
    "signature": "setSearchQuery(value: string): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "setSearchModeActive",
    "signature": "setSearchModeActive(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "onSearchResultsUpdated",
    "signature": "onSearchResultsUpdated(position: number, total: number, loadedCount: number): void",
    "arguments": [
      "position",
      "total",
      "loadedCount"
    ]
  },
  {
    "name": "onSearchLoadingChanged",
    "signature": "onSearchLoadingChanged(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "onSearchErrorChanged",
    "signature": "onSearchErrorChanged(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "scrollToMessageId",
    "signature": "scrollToMessageId(messageId: string): boolean",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "jumpToMessageId",
    "signature": "jumpToMessageId(messageId: string): void",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "refreshScrollToBottomVisibility",
    "signature": "private refreshScrollToBottomVisibility(endIndex: number): void",
    "arguments": [
      "endIndex"
    ]
  },
  {
    "name": "handleScrollToBottomPress",
    "signature": "private handleScrollToBottomPress(): void",
    "arguments": []
  },
  {
    "name": "fulfillPendingJump",
    "signature": "private fulfillPendingJump(): void",
    "arguments": []
  },
  {
    "name": "normalizeSharedMediaLink",
    "signature": "private normalizeSharedMediaLink(value: string): string",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "resolveEntityLink",
    "signature": "private resolveEntityLink(text: string, entities: TextEntity[]): string",
    "arguments": [
      "text",
      "entities"
    ]
  },
  {
    "name": "openSharedMediaLink",
    "signature": "private openSharedMediaLink(value: string): boolean",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "executeSharedMediaAction",
    "signature": "private executeSharedMediaAction(action: PendingSharedMediaAction): boolean",
    "arguments": [
      "action"
    ]
  },
  {
    "name": "fulfillPendingSharedMediaAction",
    "signature": "private fulfillPendingSharedMediaAction(): void",
    "arguments": []
  },
  {
    "name": "beginSharedMediaAction",
    "signature": "private beginSharedMediaAction(action: PendingSharedMediaAction): void",
    "arguments": [
      "action"
    ]
  },
  {
    "name": "flashSearchHit",
    "signature": "private flashSearchHit(messageId: string, index: number): void",
    "arguments": [
      "messageId",
      "index"
    ]
  },
  {
    "name": "clearSearchFlash",
    "signature": "private clearSearchFlash(): void",
    "arguments": []
  },
  {
    "name": "aboutToAppear",
    "signature": "aboutToAppear(): void",
    "arguments": []
  },
  {
    "name": "isRouteContextCurrent",
    "signature": "private isRouteContextCurrent(route: ChatScreenRouteParams): boolean",
    "arguments": [
      "route"
    ]
  },
  {
    "name": "bindChatRoute",
    "signature": "private bindChatRoute(params: ChatScreenRouteParams | undefined): void",
    "arguments": [
      "params"
    ]
  },
  {
    "name": "activateChatRoute",
    "signature": "private activateChatRoute(): void",
    "arguments": []
  },
  {
    "name": "aboutToDisappear",
    "signature": "aboutToDisappear(): void",
    "arguments": []
  },
  {
    "name": "shouldReactToStoreChange",
    "signature": "private shouldReactToStoreChange(newState: AppState, prevState: AppState): boolean",
    "arguments": [
      "newState",
      "prevState"
    ]
  },
  {
    "name": "scheduleLifecycleTask",
    "signature": "private scheduleLifecycleTask(delayMs: number, task: () => void): void",
    "arguments": [
      "delayMs",
      "task"
    ]
  },
  {
    "name": "clearTransientTimers",
    "signature": "private clearTransientTimers(): void",
    "arguments": []
  },
  {
    "name": "syncOwnedChatContext",
    "signature": "private syncOwnedChatContext(): void",
    "arguments": []
  },
  {
    "name": "ownsNavigationContext",
    "signature": "private ownsNavigationContext(): boolean",
    "arguments": []
  },
  {
    "name": "clearOwnedChatContext",
    "signature": "private clearOwnedChatContext(): void",
    "arguments": []
  },
  {
    "name": "resolveOwnedChatTitle",
    "signature": "private resolveOwnedChatTitle(): string",
    "arguments": []
  },
  {
    "name": "showOwnedChatRoute",
    "signature": "private showOwnedChatRoute(): boolean",
    "arguments": []
  },
  {
    "name": "chatTopInset",
    "signature": "private chatTopInset(): number",
    "arguments": []
  },
  {
    "name": "shouldShowPinnedMessagePanel",
    "signature": "private shouldShowPinnedMessagePanel(): boolean",
    "arguments": []
  },
  {
    "name": "chatContentStartOffset",
    "signature": "private chatContentStartOffset(): number",
    "arguments": []
  },
  {
    "name": "resetPinnedMessageState",
    "signature": "private resetPinnedMessageState(): void",
    "arguments": []
  },
  {
    "name": "applyPinnedMessageInfo",
    "signature": "private applyPinnedMessageInfo(info: PinnedMessageInfo, index: number, totalCount: number): void",
    "arguments": [
      "info",
      "index",
      "totalCount"
    ]
  },
  {
    "name": "loadSinglePinnedMessageFallback",
    "signature": "private loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void",
    "arguments": [
      "chatId",
      "lifecycleToken",
      "requestId"
    ]
  },
  {
    "name": "loadPinnedMessage",
    "signature": "private loadPinnedMessage(): void",
    "arguments": []
  },
  {
    "name": "handlePinnedMessagePress",
    "signature": "private handlePinnedMessagePress(): void",
    "arguments": []
  },
  {
    "name": "handlePinnedMessageClose",
    "signature": "private handlePinnedMessageClose(): void",
    "arguments": []
  },
  {
    "name": "pinnedMessageTitle",
    "signature": "private pinnedMessageTitle(index: number, totalCount: number): string",
    "arguments": [
      "index",
      "totalCount"
    ]
  },
  {
    "name": "pinnedMessageListItems",
    "signature": "private pinnedMessageListItems(): TgPinnedMessageListItem[]",
    "arguments": []
  },
  {
    "name": "setPinnedMessagesListVisible",
    "signature": "private setPinnedMessagesListVisible(visible: boolean): void",
    "arguments": [
      "visible"
    ]
  },
  {
    "name": "handlePinnedMessageListPress",
    "signature": "private handlePinnedMessageListPress(): void",
    "arguments": []
  },
  {
    "name": "handlePinnedListItemPress",
    "signature": "private handlePinnedListItemPress(index: number): void",
    "arguments": [
      "index"
    ]
  },
  {
    "name": "loadMorePinnedMessages",
    "signature": "private loadMorePinnedMessages(): void",
    "arguments": []
  },
  {
    "name": "computeSafeInsets",
    "signature": "private computeSafeInsets(): void",
    "arguments": []
  },
  {
    "name": "bindWindowSizeListener",
    "signature": "private bindWindowSizeListener(): void",
    "arguments": []
  },
  {
    "name": "updateTimelineContainerWidth",
    "signature": "private updateTimelineContainerWidth(windowWidthPx: number): void",
    "arguments": [
      "windowWidthPx"
    ]
  },
  {
    "name": "resetPlaybackState",
    "signature": "private resetPlaybackState(preserveListened: boolean = false): void",
    "arguments": [
      "preserveListened"
    ]
  },
  {
    "name": "setupMediaPlaybackController",
    "signature": "private setupMediaPlaybackController(): void",
    "arguments": []
  },
  {
    "name": "getCurrentMediaPlaybackHandle",
    "signature": "private getCurrentMediaPlaybackHandle(): MediaPlaybackPageHandle | undefined",
    "arguments": []
  },
  {
    "name": "notifyPlaybackRows",
    "signature": "private notifyPlaybackRows(prevVoiceId: string, prevAudioId: string, currentId: string): void",
    "arguments": [
      "prevVoiceId",
      "prevAudioId",
      "currentId"
    ]
  },
  {
    "name": "teardownMediaPlaybackController",
    "signature": "private teardownMediaPlaybackController(preserveListened: boolean = false): void",
    "arguments": [
      "preserveListened"
    ]
  },
  {
    "name": "publishNowPlayingMeta",
    "signature": "private publishNowPlayingMeta(messageId: string, contentType: MediaContentType): void",
    "arguments": [
      "messageId",
      "contentType"
    ]
  },
  {
    "name": "handlePlaybackCompleted",
    "signature": "private handlePlaybackCompleted(messageId: string, contentType: MediaContentType): void",
    "arguments": [
      "messageId",
      "contentType"
    ]
  },
  {
    "name": "deriveChatBottomBar",
    "signature": "private deriveChatBottomBar(chat: Chat, state: AppState): void",
    "arguments": [
      "chat",
      "state"
    ]
  },
  {
    "name": "bottomBarActionLabel",
    "signature": "private bottomBarActionLabel(): string",
    "arguments": []
  },
  {
    "name": "retryChatAccess",
    "signature": "private retryChatAccess(): void",
    "arguments": []
  },
  {
    "name": "bottomBarMessage",
    "signature": "private bottomBarMessage(): string",
    "arguments": []
  },
  {
    "name": "handleChatBottomBarAction",
    "signature": "private handleChatBottomBarAction(): void",
    "arguments": []
  },
  {
    "name": "applyChatAvatarPresentation",
    "signature": "private applyChatAvatarPresentation(value: ChatAvatarPresentation): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "applyChatSubtitlePresentation",
    "signature": "private applyChatSubtitlePresentation(value: ChatSubtitlePresentation): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "updateChatTopBarData",
    "signature": "private updateChatTopBarData(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "resetBotMenuState",
    "signature": "private resetBotMenuState(): void",
    "arguments": []
  },
  {
    "name": "refreshBotMenuState",
    "signature": "private refreshBotMenuState(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "handleBotMenuPress",
    "signature": "private handleBotMenuPress(): void",
    "arguments": []
  },
  {
    "name": "botMenuCommandNames",
    "signature": "private botMenuCommandNames(): string[]",
    "arguments": []
  },
  {
    "name": "botMenuCommandDescriptions",
    "signature": "private botMenuCommandDescriptions(): string[]",
    "arguments": []
  },
  {
    "name": "handleBotMenuOpenChange",
    "signature": "private handleBotMenuOpenChange(isOpen: boolean): void",
    "arguments": [
      "isOpen"
    ]
  },
  {
    "name": "handleBotMenuCommandPress",
    "signature": "private handleBotMenuCommandPress(index: number): void",
    "arguments": [
      "index"
    ]
  },
  {
    "name": "rebuildTimeline",
    "signature": "private rebuildTimeline(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "scheduleMissingReplyHydration",
    "signature": "private scheduleMissingReplyHydration(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "runMissingReplyHydration",
    "signature": "private async runMissingReplyHydration(\n    useCase: LoadRepliedMessageUseCase,\n    requests: ReplyHydrationRequest[],\n    lifecycleToken: number,\n    chatId: number\n  ): Promise<void>",
    "arguments": [
      "useCase",
      "requests",
      "lifecycleToken",
      "chatId"
    ]
  },
  {
    "name": "refreshRestoredReplySnippet",
    "signature": "private refreshRestoredReplySnippet(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "computeInitialIndex",
    "signature": "private computeInitialIndex(totalCount: number): void",
    "arguments": [
      "totalCount"
    ]
  },
  {
    "name": "guardProgrammaticScroll",
    "signature": "private guardProgrammaticScroll(durationMs: number = PROGRAMMATIC_SCROLL_GUARD_MS): void",
    "arguments": [
      "durationMs"
    ]
  },
  {
    "name": "resetPaginationState",
    "signature": "private resetPaginationState(): void",
    "arguments": []
  },
  {
    "name": "isNearTopPaginationEdge",
    "signature": "private isNearTopPaginationEdge(start: number): boolean",
    "arguments": [
      "start"
    ]
  },
  {
    "name": "isNearBottomPaginationEdge",
    "signature": "private isNearBottomPaginationEdge(end: number, totalCount: number): boolean",
    "arguments": [
      "end",
      "totalCount"
    ]
  },
  {
    "name": "armAutoPaginationUnlock",
    "signature": "private armAutoPaginationUnlock(targetIndex: number, reason: string): void",
    "arguments": [
      "targetIndex",
      "reason"
    ]
  },
  {
    "name": "maybeUnlockAutoPagination",
    "signature": "private maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void",
    "arguments": [
      "scrollOffset",
      "scrollState"
    ]
  },
  {
    "name": "handleTimelineTouch",
    "signature": "private handleTimelineTouch(event: TouchEvent): void",
    "arguments": [
      "event"
    ]
  },
  {
    "name": "shouldSuppressLoadOlder",
    "signature": "private shouldSuppressLoadOlder(): boolean",
    "arguments": []
  },
  {
    "name": "schedulePaginationRecheck",
    "signature": "private schedulePaginationRecheck(delayMs: number = 0): void",
    "arguments": [
      "delayMs"
    ]
  },
  {
    "name": "loadOlderMessages",
    "signature": "private loadOlderMessages(): void",
    "arguments": []
  },
  {
    "name": "recheckPaginationEdge",
    "signature": "private recheckPaginationEdge(): void",
    "arguments": []
  },
  {
    "name": "loadNewerMessages",
    "signature": "private loadNewerMessages(): void",
    "arguments": []
  },
  {
    "name": "maybeMarkChatRead",
    "signature": "private maybeMarkChatRead(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "notifyMediaDownloadStateChanged",
    "signature": "private notifyMediaDownloadStateChanged(fileId: number): void",
    "arguments": [
      "fileId"
    ]
  },
  {
    "name": "requestMediaDownload",
    "signature": "private requestMediaDownload(fileId: number, messageId: string = ''): void",
    "arguments": [
      "fileId",
      "messageId"
    ]
  },
  {
    "name": "cancelMediaDownload",
    "signature": "private cancelMediaDownload(fileId: number, messageId: string = ''): void",
    "arguments": [
      "fileId",
      "messageId"
    ]
  },
  {
    "name": "clearPendingMediaDownloads",
    "signature": "private clearPendingMediaDownloads(): void",
    "arguments": []
  },
  {
    "name": "isMediaDownloadPending",
    "signature": "private isMediaDownloadPending(fileId: number): boolean",
    "arguments": [
      "fileId"
    ]
  },
  {
    "name": "isMediaDownloadFailed",
    "signature": "private isMediaDownloadFailed(fileId: number): boolean",
    "arguments": [
      "fileId"
    ]
  },
  {
    "name": "effectiveAlbumPhotoDownloading",
    "signature": "private effectiveAlbumPhotoDownloading(entry: ChatTimelineEntryVO): boolean[]",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "effectiveAlbumPhotoDownloadFailed",
    "signature": "private effectiveAlbumPhotoDownloadFailed(entry: ChatTimelineEntryVO): boolean[]",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "syncResolvedPendingDownloads",
    "signature": "private syncResolvedPendingDownloads(entries: ChatTimelineEntryVO[]): void",
    "arguments": [
      "entries"
    ]
  },
  {
    "name": "rememberPendingMediaOpenIntent",
    "signature": "private rememberPendingMediaOpenIntent(kind: PendingMediaOpenKind, fileId: number, messageId: string,\n    mimeType: string = ''): void",
    "arguments": [
      "kind",
      "fileId",
      "messageId",
      "mimeType"
    ]
  },
  {
    "name": "clearPendingMediaOpenIntent",
    "signature": "private clearPendingMediaOpenIntent(fileId: number): void",
    "arguments": [
      "fileId"
    ]
  },
  {
    "name": "fulfillPendingMediaOpenIntent",
    "signature": "private fulfillPendingMediaOpenIntent(entries: ChatTimelineEntryVO[]): void",
    "arguments": [
      "entries"
    ]
  },
  {
    "name": "handleVoiceTap",
    "signature": "private handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void",
    "arguments": [
      "messageId",
      "voicePath",
      "voiceFileId"
    ]
  },
  {
    "name": "openAudioFile",
    "signature": "private openAudioFile(audioPath: string, mimeType: string): void",
    "arguments": [
      "audioPath",
      "mimeType"
    ]
  },
  {
    "name": "openDocumentFile",
    "signature": "private openDocumentFile(documentPath: string, mimeType: string): void",
    "arguments": [
      "documentPath",
      "mimeType"
    ]
  },
  {
    "name": "handleDocumentTap",
    "signature": "private handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string,\n    messageId: string = '0'): void",
    "arguments": [
      "documentPath",
      "documentFileId",
      "mimeType",
      "messageId"
    ]
  },
  {
    "name": "handleAudioTap",
    "signature": "private handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId: string = '0'): void",
    "arguments": [
      "audioPath",
      "audioFileId",
      "mimeType",
      "messageId"
    ]
  },
  {
    "name": "handleAudioSeek",
    "signature": "private handleAudioSeek(messageId: string, progress: number): void",
    "arguments": [
      "messageId",
      "progress"
    ]
  },
  {
    "name": "handleVoiceSeek",
    "signature": "private handleVoiceSeek(messageId: string, progress: number): void",
    "arguments": [
      "messageId",
      "progress"
    ]
  },
  {
    "name": "buildMediaGalleryItems",
    "signature": "private buildMediaGalleryItems(): MediaGalleryItem[]",
    "arguments": []
  },
  {
    "name": "handleMediaGalleryOpen",
    "signature": "private handleMediaGalleryOpen(messageId: string): void",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "animateMediaGalleryState",
    "signature": "private animateMediaGalleryState(isVisible: boolean, sourceMessageId: string = '0'): void",
    "arguments": [
      "isVisible",
      "sourceMessageId"
    ]
  },
  {
    "name": "refreshOpenMediaGalleryItems",
    "signature": "private refreshOpenMediaGalleryItems(): void",
    "arguments": []
  },
  {
    "name": "startReply",
    "signature": "private startReply(messageId: string, author: string, preview: string, isQuote: boolean = false): void",
    "arguments": [
      "messageId",
      "author",
      "preview",
      "isQuote"
    ]
  },
  {
    "name": "cancelReply",
    "signature": "private cancelReply(): void",
    "arguments": []
  },
  {
    "name": "applyPendingForwardTransferIfNeeded",
    "signature": "private applyPendingForwardTransferIfNeeded(): void",
    "arguments": []
  },
  {
    "name": "createChatRouteParams",
    "signature": "createChatRouteParams(chatId: number, chatTitle: string): ChatScreenRouteParams | undefined",
    "arguments": [
      "chatId",
      "chatTitle"
    ]
  },
  {
    "name": "getChatRouteToken",
    "signature": "getChatRouteToken(): number",
    "arguments": []
  },
  {
    "name": "startOwnedChatData",
    "signature": "private startOwnedChatData(route: ChatScreenRouteParams): void",
    "arguments": [
      "route"
    ]
  },
  {
    "name": "showChatOpenFailure",
    "signature": "private showChatOpenFailure(): void",
    "arguments": []
  },
  {
    "name": "startForwardMessages",
    "signature": "private startForwardMessages(messageIds: string[], author: string, preview: string, fromChatId: number): void",
    "arguments": [
      "messageIds",
      "author",
      "preview",
      "fromChatId"
    ]
  },
  {
    "name": "cancelForwardMessages",
    "signature": "private cancelForwardMessages(): void",
    "arguments": []
  },
  {
    "name": "openForwardTargetPicker",
    "signature": "private openForwardTargetPicker(messageIds: string[], author: string, preview: string): void",
    "arguments": [
      "messageIds",
      "author",
      "preview"
    ]
  },
  {
    "name": "copyMessageText",
    "signature": "private copyMessageText(text: string): void",
    "arguments": [
      "text"
    ]
  },
  {
    "name": "effectiveVoiceListened",
    "signature": "private effectiveVoiceListened(entry: ChatTimelineEntryVO): boolean",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "isActiveVoiceEntry",
    "signature": "private isActiveVoiceEntry(entry: ChatTimelineEntryVO): boolean",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "isActiveAudioEntry",
    "signature": "private isActiveAudioEntry(entry: ChatTimelineEntryVO): boolean",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "showMessageActions",
    "signature": "private showMessageActions(entry: ChatTimelineEntryVO): void",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "messageActionsPopupStateHandler",
    "signature": "private messageActionsPopupStateHandler(messageId: string): (event: PopupStateChangeParam) => void",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "closeMessageActions",
    "signature": "private closeMessageActions(): void",
    "arguments": []
  },
  {
    "name": "refreshForwardActionAvailability",
    "signature": "private refreshForwardActionAvailability(): void",
    "arguments": []
  },
  {
    "name": "messageActionItems",
    "signature": "private messageActionItems(): ChatMessageActionItem[]",
    "arguments": []
  },
  {
    "name": "messageActionsPopupWidth",
    "signature": "private messageActionsPopupWidth(): number",
    "arguments": []
  },
  {
    "name": "messageActionsPopupHeight",
    "signature": "private messageActionsPopupHeight(): number",
    "arguments": []
  },
  {
    "name": "handleMessageActionPress",
    "signature": "private handleMessageActionPress(item: ChatMessageActionItem): void",
    "arguments": [
      "item"
    ]
  },
  {
    "name": "handleSendMessage",
    "signature": "private handleSendMessage(text: string): void",
    "arguments": [
      "text"
    ]
  },
  {
    "name": "handleComposerAttachPress",
    "signature": "private handleComposerAttachPress(): void",
    "arguments": []
  },
  {
    "name": "handleAttachmentMenuOpenChange",
    "signature": "private handleAttachmentMenuOpenChange(isOpen: boolean): void",
    "arguments": [
      "isOpen"
    ]
  },
  {
    "name": "composerKeyboardPanelVisible",
    "signature": "private composerKeyboardPanelVisible(): boolean",
    "arguments": []
  },
  {
    "name": "composerAttachmentMenuLabels",
    "signature": "private composerAttachmentMenuLabels(): string[]",
    "arguments": []
  },
  {
    "name": "handleComposerAttachmentMenuItemPress",
    "signature": "private handleComposerAttachmentMenuItemPress(index: number): void",
    "arguments": [
      "index"
    ]
  },
  {
    "name": "handleAttachmentRecentPress",
    "signature": "private handleAttachmentRecentPress(item: TgAttachmentRecentItem): void",
    "arguments": [
      "item"
    ]
  },
  {
    "name": "handleComposerEmojiPress",
    "signature": "private handleComposerEmojiPress(): void",
    "arguments": []
  },
  {
    "name": "handleComposerKeyboardModePress",
    "signature": "private handleComposerKeyboardModePress(): void",
    "arguments": []
  },
  {
    "name": "handleComposerVoicePress",
    "signature": "private handleComposerVoicePress(): void",
    "arguments": []
  },
  {
    "name": "handleVoiceRecordStart",
    "signature": "private handleVoiceRecordStart(): void",
    "arguments": []
  },
  {
    "name": "handleVoiceRecordSend",
    "signature": "private handleVoiceRecordSend(): void",
    "arguments": []
  },
  {
    "name": "handleVoiceRecordCancel",
    "signature": "private handleVoiceRecordCancel(): void",
    "arguments": []
  },
  {
    "name": "handleVoiceRecordLock",
    "signature": "private handleVoiceRecordLock(): void",
    "arguments": []
  },
  {
    "name": "handleComposerEmojiSelected",
    "signature": "private handleComposerEmojiSelected(emoji: string): void",
    "arguments": [
      "emoji"
    ]
  },
  {
    "name": "handleComposerSelectionChange",
    "signature": "private handleComposerSelectionChange(start: number, end: number): void",
    "arguments": [
      "start",
      "end"
    ]
  },
  {
    "name": "handleCustomEmojiSelected",
    "signature": "private handleCustomEmojiSelected(item: CustomEmojiCellVO): void",
    "arguments": [
      "item"
    ]
  },
  {
    "name": "toCustomEmojiCellVO",
    "signature": "private toCustomEmojiCellVO(entry: StickerPanelEntry): CustomEmojiCellVO | undefined",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "fetchCustomEmojiFiles",
    "signature": "private async fetchCustomEmojiFiles(cells: CustomEmojiCellVO[], tabId: string): Promise<void>",
    "arguments": [
      "cells",
      "tabId"
    ]
  },
  {
    "name": "fetchCustomEmojiTabThumbs",
    "signature": "private async fetchCustomEmojiTabThumbs(tabs: CustomEmojiPackTabVO[]): Promise<void>",
    "arguments": [
      "tabs"
    ]
  },
  {
    "name": "loadCustomEmojiPanelIfNeeded",
    "signature": "private loadCustomEmojiPanelIfNeeded(): void",
    "arguments": []
  },
  {
    "name": "handleCustomEmojiTabSelected",
    "signature": "private handleCustomEmojiTabSelected(tabId: string): void",
    "arguments": [
      "tabId"
    ]
  },
  {
    "name": "emojiSearchLanguageCodes",
    "signature": "private emojiSearchLanguageCodes(): string[]",
    "arguments": []
  },
  {
    "name": "resetEmojiSearchState",
    "signature": "private resetEmojiSearchState(): void",
    "arguments": []
  },
  {
    "name": "handleEmojiSearchQueryChange",
    "signature": "private handleEmojiSearchQueryChange(query: string): void",
    "arguments": [
      "query"
    ]
  },
  {
    "name": "fetchEmojiSearchFiles",
    "signature": "private async fetchEmojiSearchFiles(cells: CustomEmojiCellVO[], requestId: number): Promise<void>",
    "arguments": [
      "cells",
      "requestId"
    ]
  },
  {
    "name": "handleComposerStickerPress",
    "signature": "private handleComposerStickerPress(): void",
    "arguments": []
  },
  {
    "name": "handleComposerStickerModePress",
    "signature": "private handleComposerStickerModePress(): void",
    "arguments": []
  },
  {
    "name": "handleComposerGifPress",
    "signature": "private handleComposerGifPress(): void",
    "arguments": []
  },
  {
    "name": "toStickerCellVO",
    "signature": "private toStickerCellVO(entry: StickerPanelEntry): StickerCellVO",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "toGifCellVO",
    "signature": "private toGifCellVO(entry: GifPanelEntry): StickerCellVO",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "fetchStickerPanelFiles",
    "signature": "private async fetchStickerPanelFiles(cells: StickerCellVO[], tabId: string): Promise<void>",
    "arguments": [
      "cells",
      "tabId"
    ]
  },
  {
    "name": "fetchStickerTabThumbs",
    "signature": "private async fetchStickerTabThumbs(tabs: StickerSetTabVO[]): Promise<void>",
    "arguments": [
      "tabs"
    ]
  },
  {
    "name": "loadStickerPanelIfNeeded",
    "signature": "private loadStickerPanelIfNeeded(): void",
    "arguments": []
  },
  {
    "name": "resetStickerSearchState",
    "signature": "private resetStickerSearchState(): void",
    "arguments": []
  },
  {
    "name": "handleStickerSearchQueryChange",
    "signature": "private handleStickerSearchQueryChange(query: string): void",
    "arguments": [
      "query"
    ]
  },
  {
    "name": "getStickerSearchUseCase",
    "signature": "getStickerSearchUseCase(): StickerPanelUseCase | undefined",
    "arguments": []
  },
  {
    "name": "isStickerSearchPanelActive",
    "signature": "isStickerSearchPanelActive(): boolean",
    "arguments": []
  },
  {
    "name": "getStickerSearchLanguageCodes",
    "signature": "getStickerSearchLanguageCodes(): string[]",
    "arguments": []
  },
  {
    "name": "toStickerSearchCell",
    "signature": "toStickerSearchCell(entry: StickerPanelEntry): StickerCellVO",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "setStickerSearchItems",
    "signature": "setStickerSearchItems(items: StickerCellVO[]): void",
    "arguments": [
      "items"
    ]
  },
  {
    "name": "setStickerSearchLoading",
    "signature": "setStickerSearchLoading(value: boolean): void",
    "arguments": [
      "value"
    ]
  },
  {
    "name": "applyGroupedStickerPreviewPath",
    "signature": "private applyGroupedStickerPreviewPath(cell: StickerCellVO, fileId: number, path: string): void",
    "arguments": [
      "cell",
      "fileId",
      "path"
    ]
  },
  {
    "name": "refreshGroupedStickerHomePreviews",
    "signature": "private refreshGroupedStickerHomePreviews(state: AppState): void",
    "arguments": [
      "state"
    ]
  },
  {
    "name": "requestGroupedStickerHomePreviews",
    "signature": "private requestGroupedStickerHomePreviews(cells: StickerCellVO[], visibleLimit: number): void",
    "arguments": [
      "cells",
      "visibleLimit"
    ]
  },
  {
    "name": "resetGifSearchState",
    "signature": "private resetGifSearchState(): void",
    "arguments": []
  },
  {
    "name": "handleGifSearchQueryChange",
    "signature": "private handleGifSearchQueryChange(query: string): void",
    "arguments": [
      "query"
    ]
  },
  {
    "name": "loadMoreGifSearch",
    "signature": "private loadMoreGifSearch(): void",
    "arguments": []
  },
  {
    "name": "fetchGifSearchFiles",
    "signature": "private async fetchGifSearchFiles(cells: StickerCellVO[], requestId: number): Promise<void>",
    "arguments": [
      "cells",
      "requestId"
    ]
  },
  {
    "name": "loadFavoriteStickerTab",
    "signature": "private loadFavoriteStickerTab(): void",
    "arguments": []
  },
  {
    "name": "loadPremiumStickerHomeIfNeeded",
    "signature": "private loadPremiumStickerHomeIfNeeded(): void",
    "arguments": []
  },
  {
    "name": "loadStickerSetTabs",
    "signature": "private loadStickerSetTabs(includeFavorites: boolean): void",
    "arguments": [
      "includeFavorites"
    ]
  },
  {
    "name": "handleStickerTabSelected",
    "signature": "private handleStickerTabSelected(tabId: string): void",
    "arguments": [
      "tabId"
    ]
  },
  {
    "name": "loadGifPanel",
    "signature": "private loadGifPanel(): void",
    "arguments": []
  },
  {
    "name": "handleStickerSelected",
    "signature": "private handleStickerSelected(cell: StickerCellVO): void",
    "arguments": [
      "cell"
    ]
  },
  {
    "name": "clearPendingAttachment",
    "signature": "private clearPendingAttachment(): void",
    "arguments": []
  },
  {
    "name": "startEditMessage",
    "signature": "private startEditMessage(messageId: string, originalText: string): void",
    "arguments": [
      "messageId",
      "originalText"
    ]
  },
  {
    "name": "cancelEditMessage",
    "signature": "private cancelEditMessage(): void",
    "arguments": []
  },
  {
    "name": "handleEditMessage",
    "signature": "private handleEditMessage(newText: string): void",
    "arguments": [
      "newText"
    ]
  },
  {
    "name": "handleForwardMessages",
    "signature": "private handleForwardMessages(commentText: string): void",
    "arguments": [
      "commentText"
    ]
  },
  {
    "name": "handlePinMessage",
    "signature": "private handlePinMessage(messageId: string): void",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "handleDeleteMessage",
    "signature": "private handleDeleteMessage(messageId: string): void",
    "arguments": [
      "messageId"
    ]
  },
  {
    "name": "handleSearchQueryChange",
    "signature": "private handleSearchQueryChange(query: string): void",
    "arguments": [
      "query"
    ]
  },
  {
    "name": "openSearch",
    "signature": "private openSearch(): void",
    "arguments": []
  },
  {
    "name": "closeSearch",
    "signature": "private closeSearch(): void",
    "arguments": []
  },
  {
    "name": "useSearchFlashOutline",
    "signature": "private useSearchFlashOutline(entry: ChatTimelineEntryVO): boolean",
    "arguments": [
      "entry"
    ]
  },
  {
    "name": "normalizedDraftCustomEmojiEntities",
    "signature": "private normalizedDraftCustomEmojiEntities(text: string): CustomEmojiTextEntity[]",
    "arguments": [
      "text"
    ]
  },
  {
    "name": "persistDraft",
    "signature": "private persistDraft(chatId: number): void",
    "arguments": [
      "chatId"
    ]
  },
  {
    "name": "restoreDraftFromChat",
    "signature": "private restoreDraftFromChat(): void",
    "arguments": []
  },
  {
    "name": "scheduleDraftDebounce",
    "signature": "private scheduleDraftDebounce(): void",
    "arguments": []
  },
  {
    "name": "openProfile",
    "signature": "private openProfile(): void",
    "arguments": []
  },
  {
    "name": "handleBackPress",
    "signature": "private handleBackPress(): void",
    "arguments": []
  },
  {
    "name": "saveScrollPosition",
    "signature": "private saveScrollPosition(): void",
    "arguments": []
  },
  {
    "name": "restoreScrollPosition",
    "signature": "private restoreScrollPosition(): void",
    "arguments": []
  },
  {
    "name": "isNearBottom",
    "signature": "isNearBottom(): boolean",
    "arguments": []
  },
  {
    "name": "scheduleHistoryLoad",
    "signature": "private scheduleHistoryLoad(chatId: number, attempt: number): void",
    "arguments": [
      "chatId",
      "attempt"
    ]
  },
  {
    "name": "shouldRetryHistoryLoad",
    "signature": "private shouldRetryHistoryLoad(chatId: number): boolean",
    "arguments": [
      "chatId"
    ]
  },
  {
    "name": "shouldShowHistoryLoadingPlaceholder",
    "signature": "private shouldShowHistoryLoadingPlaceholder(): boolean",
    "arguments": []
  },
  {
    "name": "requestHistoryWithRetry",
    "signature": "private requestHistoryWithRetry(chatId: number, attempt: number): void",
    "arguments": [
      "chatId",
      "attempt"
    ]
  },
  {
    "name": "captureInitialHistorySnapshot",
    "signature": "private captureInitialHistorySnapshot(state: AppState, scheduleCorrection: boolean = true): void",
    "arguments": [
      "state",
      "scheduleCorrection"
    ]
  },
  {
    "name": "buildInitialHistoryParams",
    "signature": "private buildInitialHistoryParams(chatId: number, state?: AppState): LoadChatHistoryParams",
    "arguments": [
      "chatId",
      "state"
    ]
  },
  {
    "name": "bindNavigationStack",
    "signature": "bindNavigationStack(): NavPathStack | undefined",
    "arguments": []
  }
];
