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
