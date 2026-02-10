import { formatDateSeparator } from '../../../components/Common/DateSeparator';
import { BasicDataSource } from '../../../datasources/BasicDataSource';
import { GroupedMessage, Message, MessageReaction } from '../../../models/Message';
import { ChatDetailListItem } from './ChatDetailListItem';

export interface SelectionState {
  isSelectionMode: boolean;
  selectedMessageIds: number[];
}

export function buildFlatItems(messages: Message[]): ChatDetailListItem[] {
  const TIME_THRESHOLD = 3 * 60;

  const grouped: GroupedMessage[] = messages.map((msg: Message, index: number) => {
    const prev: Message | null = index > 0 ? messages[index - 1] : null;
    const next: Message | null = index < messages.length - 1 ? messages[index + 1] : null;

    const sameSenderAsPrev = prev !== null
      && prev.senderId === msg.senderId
      && prev.isOutgoing === msg.isOutgoing
      && (msg.date - prev.date) < TIME_THRESHOLD
      && isSameDay(prev.date, msg.date);

    const sameSenderAsNext = next !== null
      && next.senderId === msg.senderId
      && next.isOutgoing === msg.isOutgoing
      && (next.date - msg.date) < TIME_THRESHOLD
      && isSameDay(msg.date, next.date);

    return new GroupedMessage(msg, !sameSenderAsPrev, !sameSenderAsNext);
  });

  const flatItems: ChatDetailListItem[] = [];
  let currentDateLabel: string = '';
  for (const item of grouped) {
    const dateLabel = formatDateSeparator(item.message.date);
    if (dateLabel !== currentDateLabel) {
      flatItems.push(new ChatDetailListItem(true, dateLabel));
      currentDateLabel = dateLabel;
    }
    flatItems.push(new ChatDetailListItem(false, '', item));
  }
  return flatItems;
}

export function findFlatIndexByMessageId(
  dataSource: BasicDataSource<ChatDetailListItem>,
  messageId: number
): number {
  for (let i = 0; i < dataSource.totalCount(); i++) {
    const item = dataSource.getData(i) as ChatDetailListItem;
    if (!item.isDateSeparator && item.groupedMessage?.message.id === messageId) {
      return i;
    }
  }
  return -1;
}

export function toggleMessageSelectionState(
  isSelectionMode: boolean,
  selectedMessageIds: number[],
  messageId: number
): SelectionState {
  if (!isSelectionMode) {
    return { isSelectionMode: true, selectedMessageIds: [messageId] };
  }

  const idx = selectedMessageIds.indexOf(messageId);
  if (idx >= 0) {
    const next = selectedMessageIds.filter((id: number) => id !== messageId);
    return {
      isSelectionMode: next.length > 0,
      selectedMessageIds: next
    };
  }

  return {
    isSelectionMode: true,
    selectedMessageIds: [...selectedMessageIds, messageId]
  };
}

export function toggleReactionState(msg: Message, emoji: string): void {
  if (emoji.length === 0) {
    const defaultEmoji = '\u{1F44D}';
    const existing = msg.reactions.find((r: MessageReaction) => r.emoji === defaultEmoji);
    if (existing) {
      existing.count++;
      existing.isMine = true;
      return;
    }
    const newReaction: MessageReaction = { emoji: defaultEmoji, count: 1, isMine: true };
    msg.reactions.push(newReaction);
    return;
  }

  const existing = msg.reactions.find((r: MessageReaction) => r.emoji === emoji);
  if (existing && existing.isMine) {
    existing.isMine = false;
    existing.count = Math.max(0, existing.count - 1);
    if (existing.count === 0) {
      msg.reactions = msg.reactions.filter((r: MessageReaction) => r.emoji !== emoji);
    }
    return;
  }
  if (existing) {
    existing.count++;
    existing.isMine = true;
    return;
  }

  const newReaction: MessageReaction = { emoji: emoji, count: 1, isMine: true };
  msg.reactions.push(newReaction);
}

function isSameDay(ts1: number, ts2: number): boolean {
  const d1 = new Date(ts1 * 1000);
  const d2 = new Date(ts2 * 1000);
  return d1.toDateString() === d2.toDateString();
}
