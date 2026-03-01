import { ChatTimelineEntryVO, ChatMessageRowVO } from './ChatTimelineVO';

export class ChatTimelineDataSource implements IDataSource {
  private items: ChatTimelineEntryVO[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ChatTimelineEntryVO {
    return this.items[index];
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

  private sameMessage(prev: ChatMessageRowVO, next: ChatMessageRowVO): boolean {
    return prev.messageId === next.messageId &&
      prev.text === next.text &&
      prev.isOutgoing === next.isOutgoing &&
      prev.isEmojiOnly === next.isEmojiOnly &&
      prev.timeText === next.timeText &&
      prev.sendStatus === next.sendStatus &&
      prev.forceBreakAll === next.forceBreakAll &&
      prev.showReplySnippet === next.showReplySnippet &&
      prev.replyAuthor === next.replyAuthor &&
      prev.replyPreview === next.replyPreview &&
      prev.replyIsOutgoing === next.replyIsOutgoing &&
      prev.replyIsQuote === next.replyIsQuote &&
      prev.contentType === next.contentType &&
      prev.caption === next.caption &&
      prev.photoPath === next.photoPath &&
      prev.photoWidth === next.photoWidth &&
      prev.photoHeight === next.photoHeight &&
      prev.videoThumbPath === next.videoThumbPath &&
      prev.videoPath === next.videoPath &&
      prev.videoDuration === next.videoDuration &&
      prev.videoWidth === next.videoWidth &&
      prev.videoHeight === next.videoHeight &&
      prev.fileName === next.fileName &&
      prev.fileSize === next.fileSize &&
      prev.mimeType === next.mimeType &&
      prev.voiceDuration === next.voiceDuration &&
      prev.voiceWaveform === next.voiceWaveform &&
      prev.isVoiceListened === next.isVoiceListened &&
      prev.stickerPath === next.stickerPath &&
      prev.stickerWidth === next.stickerWidth &&
      prev.stickerHeight === next.stickerHeight &&
      prev.isAnimatedSticker === next.isAnimatedSticker &&
      prev.isVideoSticker === next.isVideoSticker;
  }

  private sameEntry(prev: ChatTimelineEntryVO, next: ChatTimelineEntryVO): boolean {
    if (prev.key !== next.key || prev.kind !== next.kind) {
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
      if (oldItems[i].key !== newItems[i].key) {
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
      if (oldItems[i].key !== newItems[i].key) {
        return false;
      }
    }
    return true;
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

    this.items = newItems;
    this.notifyDataReloaded();
  }
}
