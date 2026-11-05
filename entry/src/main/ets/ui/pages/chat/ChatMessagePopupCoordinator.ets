// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatMessageActionItem, ChatMessageActionsController, ChatMessageActionsHost } from './ChatMessageActionsController';
import { ChatForwardSourceController } from './ChatForwardSourceController';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { ChatReactionHost, toggleMessageReaction } from './ChatReactionController';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { Chat, availableReactionKeys, chatAllowsReactions, pickerReactionKeys } from '../../../core/model/AppState';
import { MessageAvailableReactionsSnapshot } from '../../../core/model/dto/MessageDto';
import { createGetMessageAvailableReactionsUseCase } from '../../../domain/usecases/getMessageAvailableReactions';
import { localized } from '../../../core/utils/AppResource';
import { SUPPORTED_TRANSLATION_LANGUAGES } from '../../../domain/usecases/translationLanguage';

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
  // S3d.1: keys for the popup reaction row; seeded from the chat list, then replaced by the
  // per-message getMessageAvailableReactions answer.
  messageActionsReactionKeys: string[];
  // S5b (C9): selection mode state and the rendered timeline entries the actions read.
  selectionActive: boolean;
  selectedMessageIds: string[];
  dataSource: ChatTimelineDataSource;
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
    host.messageActionsReactionKeys = chatLevelPickerKeys(host);
    host.refreshForwardActionAvailability();
    refreshPickerReactionKeys(host, entry.message.messageId, host.messageActionsGeneration);
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
    host.messageActionsReactionKeys = [];
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
  return host.messageActionsReactionKeys.length > 0
    ? host.messageActionsReactionKeys
    : chatLevelPickerKeys(host);
}

export function chatLevelPickerKeys(host: ChatMessagePopupCoordinatorPort): string[] {
  // S3d: availability is chat-level state parsed from chat.available_reactions, so the picker never
  // offers a reaction TDLib would reject.
  if (!host.hasActiveChatState() || host.activeChatId === 0 || host.accountStore === undefined) {
    return [];
  }
  const chat: Chat | undefined = host.accountStore.getState().chats.chats.get(host.activeChatId);
  return chatAllowsReactions(chat) ? availableReactionKeys(chat) : [];
}

export function refreshPickerReactionKeys(host: ChatMessagePopupCoordinatorPort, messageId: string,
  generation: number): void {
  // S3d.1: ask TDLib for this message's own list (top/recent/popular). The seeded chat-level row is
  // already visible, so the request only ever enriches it; a stale answer for another popup or chat
  // is dropped by the generation/lifecycle/identity fence below.
  const gateway = host.chatGateway;
  if (gateway === undefined || messageId === '0') {
    return;
  }
  const chatId = host.activeChatId;
  const lifecycle = host.getLifecycleToken();
  createGetMessageAvailableReactionsUseCase(gateway).load(chatId, messageId)
    .then((snapshot: MessageAvailableReactionsSnapshot): void => {
      if (generation !== host.messageActionsGeneration ||
        host.getLifecycleToken() !== lifecycle ||
        host.activeChatId !== chatId ||
        host.messageActionsOpenId !== messageId) {
        return;
      }
      const accountStore = host.accountStore;
      let chat: Chat | undefined = undefined;
      if (accountStore !== undefined) {
        chat = accountStore.getState().chats.chats.get(chatId);
      }
      if (chat !== undefined && !chatAllowsReactions(chat)) {
        // A chat that forbids reactions must not gain them from a stale response.
        host.messageActionsReactionKeys = [];
        return;
      }
      host.messageActionsReactionKeys = pickerReactionKeys(chat, snapshot.top, snapshot.recent,
        snapshot.popular);
    });
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


export function messageActionTranslationLanguages(host: ChatMessagePopupCoordinatorPort): string[] {
  // The receiver is unused: the delegate contract requires the session instance.
  return SUPPORTED_TRANSLATION_LANGUAGES.slice();
}
export function messageActionTranslationLanguage(host: ChatMessagePopupCoordinatorPort): string {
  // D24: the language that Translate will use for the open message chat.
  if (host.activeChatId === 0) {
    return '';
  }
  return host.messageActionsCtrl.translationLanguageFor(host.activeChatId);
}
export function handleMessageActionTranslationLanguage(host: ChatMessagePopupCoordinatorPort,
  code: string): void {
  // Choosing a language stores it for this chat and re-requests the open message.
  const chatId = host.activeChatId;
  const entry = host.messageActionsEntry;
  if (chatId === 0 || entry === undefined) {
    return;
  }
  if (!host.messageActionsCtrl.setTranslationLanguage(chatId, code)) {
    return;
  }
  host.closeMessageActions();
  host.messageActionsCtrl.translateIntoLanguage(entry, host);
}
export function enterMessageSelection(host: ChatMessagePopupCoordinatorPort, messageId: string): void {
  // Selection mode is page UI state (ids in ChatTimelineViewState); actions reuse the existing
  // copy/forward/delete controllers so the TDLib paths and their fences stay single-sourced.
  if (messageId.length === 0) return;
  host.messageActionsGeneration++;
  host.closeMessageActions();
  host.selectionActive = true;
  host.selectedMessageIds = [messageId];
}

export function toggleMessageSelection(host: ChatMessagePopupCoordinatorPort, messageId: string): void {
  if (!host.selectionActive || messageId.length === 0) return;
  const current = host.selectedMessageIds;
  const next = current.includes(messageId)
    ? current.filter((id: string): boolean => id !== messageId)
    : current.concat([messageId]);
  host.selectedMessageIds = next;
  if (next.length === 0) {
    host.selectionActive = false;
  }
}

export function clearMessageSelection(host: ChatMessagePopupCoordinatorPort): void {
  host.selectionActive = false;
  host.selectedMessageIds = [];
}

export function selectionTitle(host: ChatMessagePopupCoordinatorPort): string {
  const count = host.selectedMessageIds.length;
  if (count === 0) return '';
  const template = localized($r('app.string.selection_count').id, '%d selected');
  return template.replace('%d', count.toString());
}

// Selected ids in the order they appear in the timeline (channel/album rows resolve to their
// rendered entries), so copy/forward/delete never depend on tap order.
function selectedEntriesInTimelineOrder(host: ChatMessagePopupCoordinatorPort): ChatTimelineEntryVO[] {
  const selected = host.selectedMessageIds;
  if (selected.length === 0) return [];
  const entries: ChatTimelineEntryVO[] = [];
  const seen: string[] = [];
  for (const entry of host.dataSource.getAllEntries()) {
    if (entry.kind !== 'message') continue;
    if (selected.indexOf(entry.message.messageId) < 0 || seen.indexOf(entry.message.messageId) >= 0) continue;
    seen.push(entry.message.messageId);
    entries.push(entry);
  }
  return entries;
}

export function copySelectedMessages(host: ChatMessagePopupCoordinatorPort): void {
  const entries = selectedEntriesInTimelineOrder(host);
  const texts: string[] = [];
  for (const entry of entries) {
    const text = entry.message.text.length > 0 ? entry.message.text : entry.message.caption;
    if (text.length > 0) texts.push(text);
  }
  if (texts.length === 0) return;
  host.messageActionsCtrl.copyMessageText(texts.join('\n'), host);
  clearMessageSelection(host);
}

export function forwardSelectedMessages(host: ChatMessagePopupCoordinatorPort): void {
  const entries = selectedEntriesInTimelineOrder(host);
  if (entries.length === 0) return;
  const chatId = host.getActiveChatId();
  if (chatId === 0) return;
  const ids: string[] = [];
  for (const entry of entries) ids.push(entry.message.messageId);
  const first = entries[0].message;
  const author = first.senderName.length > 0 ? first.senderName
    : (first.isOutgoing ? localized($r('app.string.chat_you_prefix').id, 'You')
      : localized($r('app.string.message_action').id, 'Message'));
  const previewSource = first.text.length > 0 ? first.text : first.caption;
  host.messageActionsCtrl.startForwardMessages(ids, author, previewSource, chatId, host);
  clearMessageSelection(host);
}

export function deleteSelectedMessages(host: ChatMessagePopupCoordinatorPort): void {
  const entries = selectedEntriesInTimelineOrder(host);
  if (entries.length === 0) return;
  const ids: string[] = [];
  for (const entry of entries) ids.push(entry.message.messageId);
  host.messageActionsCtrl.handleDeleteMessages(ids, host);
  clearMessageSelection(host);
}
