// ChatReactionController — optimistic reaction toggle with a single network action and rollback.
//
// The store is the only source of chips: the optimistic snapshot is written before the command and
// the previous chips are restored if the command fails. A per-target guard collapses a fast double
// tap into one command; the server snapshot (`updateMessageReactions`) then replaces whatever the
// optimistic step produced, so no local merge survives an acknowledgement.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { createSetMessageReactionsUseCase } from '../../../domain/usecases/setMessageReactions';
import {
  AppState,
  Message,
  ReactionChipData,
  chosenReactionKeys,
  toggleReactionChips
} from '../../../core/model/AppState';
import { MessageReactionsUpdatedEvent } from '../../../core/model/AppEvent';
import { ChatId, MessageId } from '../../../core/model/EntityId';

const TAG = 'ChatReaction';
const DOMAIN = 0x0021;

export interface ChatReactionHost {
  hasActiveChatState(): boolean;
  getActiveChatId(): number;
  getLifecycleToken(): number;
  accountStore?: AppStore;
  chatGateway?: TdGatewayPort;
  // Owned by the chat page context; keeps the in-flight guard across taps.
  reactionController: ChatReactionController;
}

function messageReactions(state: AppState, chatId: ChatId, messageId: MessageId): ReactionChipData[] | undefined {
  const messages = state.messages.messages.get(chatId);
  if (messages === undefined) {
    return undefined;
  }
  const message: Message | undefined = messages.get(messageId);
  return message === undefined ? undefined : message.reactions;
}

function dispatchSnapshot(store: AppStore, chatId: ChatId, messageId: MessageId,
  chips: ReactionChipData[]): void {
  const event = new MessageReactionsUpdatedEvent();
  event.chatId = chatId;
  event.messageId = messageId;
  event.reactionKeys = chips.map((chip: ReactionChipData): string => chip.key);
  event.reactionCounts = chips.map((chip: ReactionChipData): number => chip.count);
  event.reactionChosen = chips.map((chip: ReactionChipData): boolean => chip.chosen);
  event.timestamp = Date.now();
  store.dispatch(event);
}

export class ChatReactionController {
  private inFlight: Set<string> = new Set<string>();

  // Toggles one chip. Returns false when the tap was ignored (no chat, no message, already in
  // flight) so the caller does not have to guess.
  toggle(host: ChatReactionHost, messageId: MessageId, key: string): boolean {
    if (!host.hasActiveChatState()) {
      return false;
    }
    const store = host.accountStore;
    const gateway = host.chatGateway;
    const chatId = host.getActiveChatId();
    if (store === undefined || gateway === undefined || chatId === 0 || messageId === '0') {
      return false;
    }
    const before = messageReactions(store.getState(), chatId, messageId);
    if (before === undefined) {
      return false;
    }
    const requestKey = chatId.toString() + ':' + messageId + ':' + key;
    if (this.inFlight.has(requestKey)) {
      return false;
    }
    this.inFlight.add(requestKey);

    const token = host.getLifecycleToken();
    const after = toggleReactionChips(before, key);
    dispatchSnapshot(store, chatId, messageId, after);

    createSetMessageReactionsUseCase(gateway).set(chatId, messageId, chosenReactionKeys(after))
      .then(() => {
        this.inFlight.delete(requestKey);
        hilog.info(DOMAIN, TAG, 'Reaction acknowledged for message %{public}s', messageId);
      })
      .catch((error: Error) => {
        this.inFlight.delete(requestKey);
        if (token !== host.getLifecycleToken()) {
          return;
        }
        dispatchSnapshot(store, chatId, messageId, before);
        hilog.warn(DOMAIN, TAG, 'Reaction rolled back for message %{public}s: %{public}s',
          messageId, error.message);
      });
    return true;
  }
}

// Session-facing entry point: one controller per chat page owns the in-flight guard, so a fast
// double tap on the same chip never produces two commands.
export function toggleMessageReaction(host: ChatReactionHost, messageId: MessageId, key: string): void {
  host.reactionController.toggle(host, messageId, key);
}
