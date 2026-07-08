import { ChatTimelineEntryVO, ChatMessageRowVO } from './ChatTimelineVO';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatTimelineDS';

export class ChatTimelineDataSource implements IDataSource {
  private items: ChatTimelineEntryVO[] = [];
  private listeners: DataChangeListener[] = [];
  private lastPrependCount: number = 0;

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ChatTimelineEntryVO {
    return this.items[index];
  }

  getLastPrependCount(): number {
    return this.lastPrependCount;
  }

  getAllEntries(): ChatTimelineEntryVO[] {
    return this.items;
  }

  /**
   * Find the current index of an entry by its stable key.
   * Returns -1 if not found. Used for key-based scroll anchoring after prepend.
   */
  findIndexByKey(key: string): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].key === key) {
        return i;
      }
    }
    return -1;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  private notifyDataReloaded(): void {
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  private notifyDataAdd(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataAdd(index);
    }
  }

  private notifyDataDelete(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataDelete(index);
    }
  }

  private notifyDataChange(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataChange(index);
    }
  }

  /**
   * Notify LazyForEach that a specific item needs visual refresh.
   * Used for page-local state changes (playback progress, isPlaying)
   * that don't come from the data store.
   */
  notifyItemChangedByMessageId(messageId: string): void {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].kind === 'message' && this.items[i].message.messageId === messageId) {
        this.notifyDataChange(i);
        return;
      }
    }
  }

  private sameStringArray(prev: string[], next: string[]): boolean {
    if (prev.length !== next.length) {
      return false;
    }
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== next[i]) {
        return false;
      }
    }
    return true;
  }

  private sameNumberArray(prev: number[], next: number[]): boolean {
    if (prev.length !== next.length) {
      return false;
    }
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== next[i]) {
        return false;
      }
    }
    return true;
  }

  private sameBoolArray(prev: boolean[], next: boolean[]): boolean {
    if (prev.length !== next.length) {
      return false;
    }
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== next[i]) {
        return false;
      }
    }
    return true;
  }

  private sameMessage(prev: ChatMessageRowVO, next: ChatMessageRowVO): boolean {
    return prev.messageId === next.messageId &&
      prev.text === next.text &&
      prev.isOutgoing === next.isOutgoing &&
      prev.isEmojiOnly === next.isEmojiOnly &&
      prev.timeText === next.timeText &&
      prev.sendStatus === next.sendStatus &&
      prev.forceBreakAll === next.forceBreakAll &&
      this.sameNumberArray(prev.quoteOffsets, next.quoteOffsets) &&
      this.sameNumberArray(prev.quoteLengths, next.quoteLengths) &&
      this.sameBoolArray(prev.quoteCollapsedFlags, next.quoteCollapsedFlags) &&
      prev.senderName === next.senderName &&
      prev.senderColorHex === next.senderColorHex &&
      prev.showSenderName === next.showSenderName &&
      prev.showReplySnippet === next.showReplySnippet &&
      prev.replyAuthor === next.replyAuthor &&
      prev.replyAuthorColorHex === next.replyAuthorColorHex &&
      prev.replyPreview === next.replyPreview &&
      prev.replyIsOutgoing === next.replyIsOutgoing &&
      prev.replyIsQuote === next.replyIsQuote &&
      prev.replyHasThumbnail === next.replyHasThumbnail &&
      prev.replyThumbnailSrc === next.replyThumbnailSrc &&
      prev.contentType === next.contentType &&
      prev.caption === next.caption &&
      this.sameNumberArray(prev.captionQuoteOffsets, next.captionQuoteOffsets) &&
      this.sameNumberArray(prev.captionQuoteLengths, next.captionQuoteLengths) &&
      this.sameBoolArray(prev.captionQuoteCollapsedFlags, next.captionQuoteCollapsedFlags) &&
      prev.photoPath === next.photoPath &&
      prev.photoMinithumb === next.photoMinithumb &&
      prev.photoFileId === next.photoFileId &&
      prev.hasLocalPhoto === next.hasLocalPhoto &&
      prev.isPhotoDownloading === next.isPhotoDownloading &&
      prev.photoDownloadProgress === next.photoDownloadProgress &&
      prev.photoWidth === next.photoWidth &&
      prev.photoHeight === next.photoHeight &&
      this.sameStringArray(prev.albumPhotoPaths, next.albumPhotoPaths) &&
      this.sameStringArray(prev.albumPhotoMinithumbs, next.albumPhotoMinithumbs) &&
      this.sameNumberArray(prev.albumPhotoFileIds, next.albumPhotoFileIds) &&
      this.sameBoolArray(prev.albumPhotoHasLocal, next.albumPhotoHasLocal) &&
      this.sameBoolArray(prev.albumPhotoDownloading, next.albumPhotoDownloading) &&
      this.sameNumberArray(prev.albumPhotoDownloadProgress, next.albumPhotoDownloadProgress) &&
      this.sameNumberArray(prev.albumPhotoWidths, next.albumPhotoWidths) &&
      this.sameNumberArray(prev.albumPhotoHeights, next.albumPhotoHeights) &&
      prev.videoThumbPath === next.videoThumbPath &&
      prev.videoMinithumb === next.videoMinithumb &&
      prev.videoPath === next.videoPath &&
      prev.videoDuration === next.videoDuration &&
      prev.videoWidth === next.videoWidth &&
      prev.videoHeight === next.videoHeight &&
      prev.isVideoDownloading === next.isVideoDownloading &&
      prev.videoDownloadProgress === next.videoDownloadProgress &&
      prev.documentPath === next.documentPath &&
      prev.documentFileId === next.documentFileId &&
      prev.isDocumentDownloading === next.isDocumentDownloading &&
      prev.documentDownloadProgress === next.documentDownloadProgress &&
      prev.audioPath === next.audioPath &&
      prev.audioFileId === next.audioFileId &&
      prev.isAudioDownloading === next.isAudioDownloading &&
      prev.audioDownloadProgress === next.audioDownloadProgress &&
      prev.audioDuration === next.audioDuration &&
      prev.audioTitle === next.audioTitle &&
      prev.audioPerformer === next.audioPerformer &&
      prev.fileName === next.fileName &&
      prev.fileSize === next.fileSize &&
      prev.mimeType === next.mimeType &&
      prev.voicePath === next.voicePath &&
      prev.voiceFileId === next.voiceFileId &&
      prev.isVoiceDownloading === next.isVoiceDownloading &&
      prev.voiceDownloadProgress === next.voiceDownloadProgress &&
      prev.voiceDuration === next.voiceDuration &&
      prev.voiceWaveform === next.voiceWaveform &&
      prev.isVoiceListened === next.isVoiceListened &&
      prev.stickerPath === next.stickerPath &&
      prev.stickerWidth === next.stickerWidth &&
      prev.stickerHeight === next.stickerHeight &&
      prev.isAnimatedSticker === next.isAnimatedSticker &&
      prev.isVideoSticker === next.isVideoSticker &&
      prev.reserveAvatarLane === next.reserveAvatarLane &&
      prev.showAvatar === next.showAvatar &&
      prev.avatarImageSrc === next.avatarImageSrc &&
      prev.avatarInitials === next.avatarInitials &&
      prev.avatarColorIndex === next.avatarColorIndex &&
      prev.topSpacing === next.topSpacing &&
      prev.groupingFlags === next.groupingFlags;
  }

  private sameEntry(prev: ChatTimelineEntryVO, next: ChatTimelineEntryVO): boolean {
    // Identity by stableKey: the full key carries the media render stamp and
    // MUST differ for a changed row (LazyForEach only rebuilds on a new key)
    if (prev.stableKey !== next.stableKey || prev.kind !== next.kind) {
      return false;
    }
    if (prev.key !== next.key) {
      return false;
    }
    if (prev.kind === 'date') {
      return prev.dateText === next.dateText;
    }
    if (prev.kind === 'unread') {
      return prev.unreadText === next.unreadText;
    }
    return this.sameMessage(prev.message, next.message);
  }

  private hasSameOrder(oldItems: ChatTimelineEntryVO[], newItems: ChatTimelineEntryVO[]): boolean {
    if (oldItems.length !== newItems.length) {
      return false;
    }
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].stableKey !== newItems[i].stableKey) {
        return false;
      }
    }
    return true;
  }

  private isAppendToTail(oldItems: ChatTimelineEntryVO[], newItems: ChatTimelineEntryVO[]): boolean {
    if (newItems.length <= oldItems.length) {
      return false;
    }
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].stableKey !== newItems[i].stableKey) {
        return false;
      }
    }
    return true;
  }

  private isPrependToHead(oldItems: ChatTimelineEntryVO[], newItems: ChatTimelineEntryVO[]): boolean {
    if (newItems.length <= oldItems.length) {
      return false;
    }
    const offset = newItems.length - oldItems.length;
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].stableKey !== newItems[i + offset].stableKey) {
        return false;
      }
    }
    return true;
  }

  /**
   * Anchor-based prepend detection.
   * Finds the first MESSAGE key from oldItems in newItems.
   * Returns the number of items prepended (offset), or -1 if not a prepend.
   * More robust than isPrependToHead — tolerates unread marker changes,
   * date separator key mutations, and showSenderName recalculation.
   */
  private detectPrependByAnchor(oldItems: ChatTimelineEntryVO[], newItems: ChatTimelineEntryVO[]): number {
    if (newItems.length <= oldItems.length || oldItems.length === 0) {
      return -1;
    }
    // Find the first stable message key in old items
    let anchorKey = '';
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].kind === 'message') {
        anchorKey = oldItems[i].key;
        break;
      }
    }
    if (anchorKey.length === 0) {
      return -1;
    }
    // Find that key in new items
    for (let i = 0; i < newItems.length; i++) {
      if (newItems[i].key === anchorKey) {
        // Verify: at least a few subsequent message keys match
        let verified = 0;
        let oldIdx = 0;
        let newIdx = i;
        while (oldIdx < oldItems.length && newIdx < newItems.length && verified < 5) {
          if (oldItems[oldIdx].kind !== 'message') {
            oldIdx++;
            continue;
          }
          if (newItems[newIdx].kind !== 'message') {
            newIdx++;
            continue;
          }
          if (oldItems[oldIdx].key !== newItems[newIdx].key) {
            return -1; // Keys diverged — not a prepend
          }
          verified++;
          oldIdx++;
          newIdx++;
        }
        if (verified >= 2) {
          return i; // Number of prepended entries
        }
        return -1;
      }
    }
    return -1;
  }

  private isTrimFromTail(oldItems: ChatTimelineEntryVO[], newItems: ChatTimelineEntryVO[]): boolean {
    if (newItems.length >= oldItems.length) {
      return false;
    }
    for (let i = 0; i < newItems.length; i++) {
      if (oldItems[i].key !== newItems[i].key) {
        return false;
      }
    }
    return true;
  }

  applyDiff(newItems: ChatTimelineEntryVO[]): void {
    this.lastPrependCount = 0;
    const oldItems = this.items;

    if (oldItems.length === 0) {
      this.items = newItems;
      for (let i = 0; i < newItems.length; i++) {
        this.notifyDataAdd(i);
      }
      return;
    }

    if (newItems.length === 0) {
      const oldCount = oldItems.length;
      this.items = [];
      for (let i = oldCount - 1; i >= 0; i--) {
        this.notifyDataDelete(i);
      }
      return;
    }

    if (this.hasSameOrder(oldItems, newItems)) {
      this.items = newItems;
      for (let i = 0; i < newItems.length; i++) {
        if (!this.sameEntry(oldItems[i], newItems[i])) {
          this.notifyDataChange(i);
        }
      }
      return;
    }

    if (this.isAppendToTail(oldItems, newItems)) {
      this.items = newItems;
      for (let i = 0; i < oldItems.length; i++) {
        if (!this.sameEntry(oldItems[i], newItems[i])) {
          this.notifyDataChange(i);
        }
      }
      for (let i = oldItems.length; i < newItems.length; i++) {
        this.notifyDataAdd(i);
      }
      return;
    }

    if (this.isTrimFromTail(oldItems, newItems)) {
      this.items = newItems;
      for (let i = 0; i < newItems.length; i++) {
        if (!this.sameEntry(oldItems[i], newItems[i])) {
          this.notifyDataChange(i);
        }
      }
      for (let i = oldItems.length - 1; i >= newItems.length; i--) {
        this.notifyDataDelete(i);
      }
      return;
    }

    if (this.isPrependToHead(oldItems, newItems)) {
      const offset = newItems.length - oldItems.length;
      this.lastPrependCount = offset;
      hilog.info(DOMAIN, TAG,
        'applyDiff: PREPEND path, offset=%{public}d old=%{public}d new=%{public}d',
        offset, oldItems.length, newItems.length);
      // Official HarmonyOS pattern: insert one item at a time via splice + notifyDataAdd.
      // maintainVisibleContentPosition only tracks individual inserts, not bulk array replacement.
      // Insert in reverse order at index 0 so items end up in correct order.
      for (let i = offset - 1; i >= 0; i--) {
        this.items.splice(0, 0, newItems[i]);
        this.notifyDataAdd(0);
      }
      // Update existing items if content changed (they shifted by offset)
      for (let i = 0; i < oldItems.length; i++) {
        if (!this.sameEntry(oldItems[i], newItems[i + offset])) {
          this.items[i + offset] = newItems[i + offset];
          this.notifyDataChange(i + offset);
        }
      }
      return;
    }

    // Anchor-based prepend: tolerates unread/date key mutations
    const anchorOffset = this.detectPrependByAnchor(oldItems, newItems);
    if (anchorOffset > 0) {
      this.lastPrependCount = anchorOffset;
      hilog.info(DOMAIN, TAG,
        'applyDiff: ANCHOR-PREPEND path, offset=%{public}d old=%{public}d new=%{public}d',
        anchorOffset, oldItems.length, newItems.length);
      // Per-item insert in reverse order at index 0
      for (let i = anchorOffset - 1; i >= 0; i--) {
        this.items.splice(0, 0, newItems[i]);
        this.notifyDataAdd(0);
      }
      // Update existing items that shifted
      for (let i = 0; i < oldItems.length; i++) {
        const newIdx = i + anchorOffset;
        if (newIdx < newItems.length && !this.sameEntry(oldItems[i], newItems[newIdx])) {
          this.items[newIdx] = newItems[newIdx];
          this.notifyDataChange(newIdx);
        }
      }
      // Append any tail items beyond old range
      for (let i = oldItems.length + anchorOffset; i < newItems.length; i++) {
        this.items.push(newItems[i]);
        this.notifyDataAdd(i);
      }
      return;
    }

    hilog.warn(DOMAIN, TAG,
      'applyDiff: FALLBACK to notifyDataReloaded, old=%{public}d new=%{public}d oldKey0=%{public}s newKey0=%{public}s',
      oldItems.length, newItems.length,
      oldItems.length > 0 ? oldItems[0].key : 'none',
      newItems.length > 0 ? newItems[0].key : 'none');
    this.items = newItems;
    this.notifyDataReloaded();
  }
}
