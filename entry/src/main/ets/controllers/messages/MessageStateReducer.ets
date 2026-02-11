import { Chat } from '../../models/Chat';
import { Message } from '../../models/Message';

export function sortDialogs(dialogs: Chat[]): void {
  dialogs.sort((a: Chat, b: Chat): number => {
    if (a.order > b.order) return -1;
    if (a.order < b.order) return 1;
    return 0;
  });
}

export function upsertIncomingMessage(existing: Message[], incoming: Message): Message[] {
  const alreadyExists: boolean = existing.some((m: Message): boolean => m.id === incoming.id);
  if (alreadyExists) {
    return existing;
  }

  const next: Message[] = [...existing, incoming];
  next.sort((a: Message, b: Message): number => a.id - b.id);
  return next;
}

export function removeMessages(existing: Message[], deletedIds: number[]): Message[] {
  const deletedSet: Set<number> = new Set<number>(deletedIds);
  return existing.filter((m: Message): boolean => !deletedSet.has(m.id));
}

/**
 * Replace a temporary (local) message with the server-confirmed message.
 * TDLib fires updateMessageSendSucceeded with the old temporary ID and the
 * new server-assigned message. This function swaps them in the message list.
 */
export function replaceTemporaryMessage(existing: Message[], oldMessageId: number, confirmed: Message): Message[] {
  const idx: number = existing.findIndex((m: Message): boolean => m.id === oldMessageId);
  if (idx >= 0) {
    existing[idx] = confirmed;
  } else {
    // Temp message already removed or never cached — just insert
    existing.push(confirmed);
  }
  existing.sort((a: Message, b: Message): number => a.id - b.id);
  return existing;
}
