// Multi-sender typing model helpers (C2 remainder).
// TDLib sends one chatAction per sender (updateChatAction), so a group can have several peers typing at
// once; iOS keeps the whole set and formats "A, B and 3 others". These helpers are pure so both the
// reducer and the top-bar formatter share one rule and stay testable without ArkUI.

import { ChatActivitySender, ChatTypingInfo } from './AppState';

export const TYPING_MAX_SENDERS: number = 5;

// Applies one activity to the per-chat set. Returns undefined when the last sender cancels, so the
// reducer can drop the map entry instead of keeping an empty shell.
export function applyTypingAction(info: ChatTypingInfo | undefined, senderUserId: number,
  actionType: string, timestamp: number): ChatTypingInfo | undefined {
  // Legacy or test-constructed info may carry only the scalar fields; treat that as one sender.
  const senders: ChatActivitySender[] = info === undefined ? [] : activeSenders(info);
  const next = new ChatTypingInfo();
  for (const sender of senders) {
    if (sender.userId !== senderUserId) {
      next.senders.push(sender);
    }
  }
  if (actionType !== 'cancel') {
    const activity = new ChatActivitySender();
    activity.userId = senderUserId;
    activity.actionType = actionType;
    activity.timestamp = timestamp;
    next.senders.push(activity);
    // Keep the newest few; the header never renders more than a handful of names.
    next.senders.sort((left: ChatActivitySender, right: ChatActivitySender): number =>
      right.timestamp - left.timestamp);
    if (next.senders.length > TYPING_MAX_SENDERS) {
      next.senders = next.senders.slice(0, TYPING_MAX_SENDERS);
    }
  }
  if (next.senders.length === 0) {
    return undefined;
  }
  const latest = next.senders[0];
  next.senderUserId = latest.userId;
  next.actionType = latest.actionType;
  next.timestamp = latest.timestamp;
  return next;
}

// "A", "A and B", "A and 3 others" — the caller resolves display names and localized labels.
// Normalizes an info object into its sender set, falling back to the scalar fields.
export function activeSenders(info: ChatTypingInfo): ChatActivitySender[] {
  if (Array.isArray(info.senders) && info.senders.length > 0) {
    return info.senders.slice();
  }
  if (info.senderUserId <= 0) {
    return [];
  }
  const single = new ChatActivitySender();
  single.userId = info.senderUserId;
  single.actionType = info.actionType;
  single.timestamp = info.timestamp;
  return [single];
}

export function formatTypingActors(names: string[], andLabel: string, othersLabel: string): string {
  const known: string[] = names.filter((name: string) => name.length > 0);
  if (known.length === 0) {
    return '';
  }
  if (known.length === 1) {
    return known[0];
  }
  if (known.length === 2) {
    return known[0] + ' ' + andLabel + ' ' + known[1];
  }
  return known[0] + ' ' + andLabel + ' ' + (known.length - 1).toString() + ' ' + othersLabel;
}

// True when every sender shows the plain typing activity; a recording/uploading peer flips the mode.
export function typingSetIsPlainTyping(info: ChatTypingInfo): boolean {
  const senders: ChatActivitySender[] = activeSenders(info);
  if (senders.length === 0) {
    return info.actionType === 'typing';
  }
  for (const sender of senders) {
    if (sender.actionType !== 'typing') {
      return false;
    }
  }
  return true;
}
