// Blocked senders list paging — Settings → Blocked Users (H8).
// getBlockedMessageSenders(block_list, offset, limit) pages by offset; total_count reports the real
// size, so "show more" is driven by loaded-versus-total, never by a short page alone.

import { BlockedSenderDto } from '../../core/model/dto/BlockedSenderDto';

export function blockedSenderKey(sender: BlockedSenderDto): string {
  return sender.senderType + ':' + sender.senderId.toString();
}

// Appends a page, dropping entries the list already shows (TDLib may repeat a sender between pages
// if the block list changes while paging).
export function mergeBlockedSenders(existing: BlockedSenderDto[], page: BlockedSenderDto[]): BlockedSenderDto[] {
  const merged: BlockedSenderDto[] = [];
  const seen: Set<string> = new Set<string>();
  for (const sender of existing) {
    const key = blockedSenderKey(sender);
    if (!seen.has(key)) {
      seen.add(key);
      merged.push(sender);
    }
  }
  for (const sender of page) {
    const key = blockedSenderKey(sender);
    if (!seen.has(key)) {
      seen.add(key);
      merged.push(sender);
    }
  }
  return merged;
}

export function hasMoreBlockedSenders(loadedCount: number, totalCount: number): boolean {
  return totalCount > 0 && loadedCount < totalCount;
}
