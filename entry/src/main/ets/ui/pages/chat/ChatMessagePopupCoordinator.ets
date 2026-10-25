// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatMessageActionItem, ChatMessageActionsController, ChatMessageActionsHost } from './ChatMessageActionsController';
import { ChatForwardSourceController } from './ChatForwardSourceController';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { ChatReactionHost, toggleMessageReaction } from './ChatReactionController';
import { Chat, availableReactionKeys, chatAllowsReactions } from '../../../core/model/AppState';

export interface ChatMessagePopupCoordinatorPort extends ChatMessageActionsHost, ChatReactionHost {
  activeChatId: number;
  botMenuOpen: boolean;
  forwardSourceCtrl: ChatForwardSourceController;
  messageActionsCtrl: ChatMessageActionsController;
  messageActionsEntry: ChatTimelineEntryVO | undefined;
  messageActionsForwardState: string;
  messageActionsGeneration: number;
  messageActionsLifecycle: number;
  messageActionsOpenId: string;
  messageActionsSourceChatId: number;
  messageActionsUseCase?: ForwardMessagesUseCase;
  timelineContainerWidth: number;
  closeMessageActions(): void;
  getLifecycleToken(): number;
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined;
  hasActiveChatState(): boolean;
  messageActionItems(): ChatMessageActionItem[];
  refreshForwardActionAvailability(): void;
}

export function startReply(host: ChatMessagePopupCoordinatorPort, messageId: string, author: string, preview: string, isQuote: boolean = false): void {
    host.messageActionsCtrl.startReply(messageId, author, preview, isQuote, host);
  }

export function cancelReply(host: ChatMessagePopupCoordinatorPort): void {
    host.messageActionsCtrl.cancelReply(host);
  }

export function applyPendingForwardTransferIfNeeded(host: ChatMessagePopupCoordinatorPort): void {
    host.messageActionsCtrl.applyPendingForwardTransferIfNeeded(host);
  }

export function startForwardMessages(host: ChatMessagePopupCoordinatorPort, messageIds: string[], author: string, preview: string, fromChatId: number): void {
    host.messageActionsCtrl.startForwardMessages(messageIds, author, preview, fromChatId,
      host);
  }

export function cancelForwardMessages(host: ChatMessagePopupCoordinatorPort): void {
    host.messageActionsCtrl.cancelForwardMessages(host);
  }

export function openForwardTargetPicker(host: ChatMessagePopupCoordinatorPort, messageIds: string[], author: string, preview: string): void {
    host.messageActionsCtrl.openForwardTargetPicker(messageIds, author, preview, host);
  }

export function copyMessageText(host: ChatMessagePopupCoordinatorPort, text: string): void {
    host.messageActionsCtrl.copyMessageText(text, host);
  }

export function showMessageActions(host: ChatMessagePopupCoordinatorPort, entry: ChatTimelineEntryVO): void {
    host.messageActionsCtrl.cancelPendingMessageActions();
    host.botMenuOpen = false;
    host.messageActionsGeneration++;
    host.messageActionsEntry = entry;
    host.messageActionsSourceChatId = host.activeChatId;
    host.messageActionsLifecycle = host.getLifecycleToken();
    host.messageActionsUseCase = host.getSourceForwardUseCase();
    host.messageActionsOpenId = entry.message.messageId;
    host.refreshForwardActionAvailability();
  }

export function messageActionsPopupStateHandler(host: ChatMessagePopupCoordinatorPort, messageId: string): (event: PopupStateChangeParam) => void {
    const generation = host.messageActionsGeneration;
    return (event: PopupStateChangeParam): void => {
      if (!event.isVisible && generation === host.messageActionsGeneration && host.messageActionsOpenId === messageId) {
        host.closeMessageActions();
      }
    };
  }

export function closeMessageActions(host: ChatMessagePopupCoordinatorPort): void {
    host.messageActionsGeneration++;
    host.forwardSourceCtrl.cancel();
    host.messageActionsOpenId = '';
    host.messageActionsEntry = undefined;
    host.messageActionsUseCase = undefined;
    host.messageActionsForwardState = 'loading';
  }

export function refreshForwardActionAvailability(host: ChatMessagePopupCoordinatorPort): void {
    const entry = host.messageActionsEntry;
    const useCase = host.getSourceForwardUseCase();
    host.forwardSourceCtrl.cancel();
    if (entry === undefined || useCase === undefined) {
      host.messageActionsForwardState = 'unavailable';
      return;
    }
    const sourceChatId = host.activeChatId;
    const lifecycle = host.getLifecycleToken();
    const generation = host.messageActionsGeneration;
    host.forwardSourceCtrl.load(useCase, sourceChatId, [entry.message.messageId], (): boolean =>
      generation === host.messageActionsGeneration && entry === host.messageActionsEntry &&
      entry.message.messageId === host.messageActionsOpenId && lifecycle === host.getLifecycleToken() &&
      sourceChatId === host.activeChatId && useCase === host.getSourceForwardUseCase(),
      (state: string): void => { host.messageActionsForwardState = state; });
  }

export function messageActionItems(host: ChatMessagePopupCoordinatorPort): ChatMessageActionItem[] {
    if (host.messageActionsEntry === undefined) {
      return [];
    }
    const items = host.messageActionsCtrl.buildMessageActionItems(host.messageActionsEntry, host.messageActionsForwardState);
    for (const item of items) item.contextToken = host.messageActionsGeneration;
    return items;
  }

export function messageActionsPopupWidth(host: ChatMessagePopupCoordinatorPort): number {
    return Math.min(260, host.timelineContainerWidth - TgUiTokens.COMPOSER_SIDE_INSET * 2);
  }

export function messageActionsPopupHeight(host: ChatMessagePopupCoordinatorPort): number {
    return Math.min(host.messageActionItems().length, TgUiTokens.COMPOSER_BOT_POPUP_MAX_VISIBLE_ROWS) *
      TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT;
  }

export function handleMessageActionPress(host: ChatMessagePopupCoordinatorPort, item: ChatMessageActionItem): void {
    const entry = host.messageActionsEntry;
    if (!host.hasActiveChatState() || host.messageActionsSourceChatId !== host.activeChatId ||
      host.messageActionsLifecycle !== host.getLifecycleToken() ||
      host.messageActionsUseCase !== host.getSourceForwardUseCase()) {
      host.closeMessageActions();
      return;
    }
    if (entry === undefined || item.sourceMessageId !== entry.message.messageId ||
      item.contextToken !== host.messageActionsGeneration || !item.enabled) {
      return;
    }
    if (item.id === 'forwardRetry') {
      if (host.messageActionsForwardState === 'unavailable') host.refreshForwardActionAvailability();
      return;
    }
    if (item.id === 'forward' && host.messageActionsForwardState !== 'allowed') return;
    host.closeMessageActions();
    host.messageActionsCtrl.handleMessageActionPress(item.id, entry, host);
  }

export function startEditMessage(host: ChatMessagePopupCoordinatorPort, messageId: string, originalText: string): void {
    host.messageActionsCtrl.startEditMessage(messageId, originalText, host);
  }

export function cancelEditMessage(host: ChatMessagePopupCoordinatorPort): void {
    host.messageActionsCtrl.cancelEditMessage(host);
  }

export function handleEditMessage(host: ChatMessagePopupCoordinatorPort, newText: string): void {
    host.messageActionsCtrl.handleEditMessage(newText, host);
  }

export function handleForwardMessages(host: ChatMessagePopupCoordinatorPort, commentText: string): void {
    host.messageActionsCtrl.handleForwardMessages(commentText, host);
  }

export function handlePinMessage(host: ChatMessagePopupCoordinatorPort, messageId: string): void {
    host.messageActionsCtrl.handlePinMessage(messageId, host);
  }

export function handleDeleteMessage(host: ChatMessagePopupCoordinatorPort, messageId: string): void {
    host.messageActionsCtrl.handleDeleteMessage(messageId, host);
  }

export function messageActionReactionKeys(host: ChatMessagePopupCoordinatorPort): string[] {
  // S3d: availability is chat-level state parsed from chat.available_reactions, so the picker never
  // offers a reaction TDLib would reject.
  if (!host.hasActiveChatState() || host.activeChatId === 0 || host.accountStore === undefined) {
    return [];
  }
  const chat = host.accountStore.getState().chats.chats.get(host.activeChatId);
  return chatAllowsReactions(chat) ? availableReactionKeys(chat) : [];
}

export function handleMessageActionReaction(host: ChatMessagePopupCoordinatorPort, key: string): void {
  // The popup closes first so the optimistic footer update is visible instead of being blocked by
  // the menu; the controller owns sending and rollback.
  const entry = host.messageActionsEntry;
  if (entry === undefined || key.length === 0) {
    return;
  }
  const messageId = entry.message.messageId;
  host.closeMessageActions();
  toggleMessageReaction(host, messageId, key);
}
