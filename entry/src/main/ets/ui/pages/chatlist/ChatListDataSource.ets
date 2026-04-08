// ChatListDataSource — IDataSource implementation for LazyForEach
// Wraps ChatItemVO[] and notifies framework of data changes

import { ChatItemVO } from './ChatItemVO';

export class ChatListDataSource implements IDataSource {
  private items: ChatItemVO[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ChatItemVO {
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

  private isSameChatRow(prev: ChatItemVO, next: ChatItemVO): boolean {
    // Note: avatarColor (Resource) is excluded — reference comparison is unreliable for Resource objects.
    // Each $r() call creates a new object, so === would always return false.
    return prev.chatId === next.chatId &&
      prev.title === next.title &&
      prev.initials === next.initials &&
        prev.avatarImagePath === next.avatarImagePath &&
        prev.avatarOnline === next.avatarOnline &&
        prev.isVerified === next.isVerified &&
        prev.lastMessage === next.lastMessage &&
        prev.previewPrefix === next.previewPrefix &&
      prev.previewPrefixStyle === next.previewPrefixStyle &&
      prev.formattedTime === next.formattedTime &&
      prev.unreadCount === next.unreadCount &&
      prev.isPinned === next.isPinned &&
      prev.isLastPinned === next.isLastPinned &&
      prev.isMuted === next.isMuted &&
      prev.sendStatus === next.sendStatus &&
      prev.isGroup === next.isGroup &&
      prev.isTyping === next.isTyping &&
      prev.typingText === next.typingText &&
      prev.isDraft === next.isDraft &&
      prev.hasMention === next.hasMention &&
      prev.isScam === next.isScam &&
      prev.isFake === next.isFake &&
      prev.isSecret === next.isSecret;
  }

  private hasSameOrder(oldItems: ChatItemVO[], newItems: ChatItemVO[]): boolean {
    if (oldItems.length !== newItems.length) {
      return false;
    }
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].chatId !== newItems[i].chatId) {
        return false;
      }
    }
    return true;
  }

  private isAppendToTail(oldItems: ChatItemVO[], newItems: ChatItemVO[]): boolean {
    if (newItems.length <= oldItems.length) {
      return false;
    }
    for (let i = 0; i < oldItems.length; i++) {
      if (oldItems[i].chatId !== newItems[i].chatId) {
        return false;
      }
    }
    return true;
  }

  private isTrimFromTail(oldItems: ChatItemVO[], newItems: ChatItemVO[]): boolean {
    if (newItems.length >= oldItems.length) {
      return false;
    }
    for (let i = 0; i < newItems.length; i++) {
      if (oldItems[i].chatId !== newItems[i].chatId) {
        return false;
      }
    }
    return true;
  }

  /**
   * Incremental update path for LazyForEach.
   * Avoids full onDataReloaded() when only cell content changes without reorder.
   */
  applyDiff(newItems: ChatItemVO[]): void {
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
        if (!this.isSameChatRow(oldItems[i], newItems[i])) {
          this.notifyDataChange(i);
        }
      }
      return;
    }

    if (this.isAppendToTail(oldItems, newItems)) {
      this.items = newItems;
      for (let i = 0; i < oldItems.length; i++) {
        if (!this.isSameChatRow(oldItems[i], newItems[i])) {
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
        if (!this.isSameChatRow(oldItems[i], newItems[i])) {
          this.notifyDataChange(i);
        }
      }
      for (let i = oldItems.length - 1; i >= newItems.length; i--) {
        this.notifyDataDelete(i);
      }
      return;
    }

    // Fallback for reorder/move-heavy updates.
    this.items = newItems;
    this.notifyDataReloaded();
  }

  reload(newItems: ChatItemVO[]): void {
    this.items = newItems;
    this.notifyDataReloaded();
  }
}
