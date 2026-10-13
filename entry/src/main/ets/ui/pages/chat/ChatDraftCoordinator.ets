// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppStore } from '../../../core/store/AppStore';
import { resolveSenderName, resolveReplyPreview } from './ChatTimelineVO';
import { customEmojiEntitiesEqual, normalizeCustomEmojiEntitiesForSubstring } from '../../tg_ui/utils/TgCustomEmojiDraftPolicy';
import { createSetChatDraftCommand, CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { TdObject } from '../../../models/TdTypes';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatDraftCoordinatorPort {
  accountStore?: AppStore;
  activeChatId: number;
  composerDraftText: string;
  customEmojiDraftEntities: CustomEmojiTextEntity[];
  draftDebounceTimerId: number;
  isEditingMessage: boolean;
  isForwardingMessages: boolean;
  pageLifecycleToken: number;
  replyToMessageId: string;
  routeChatId: number;
  normalizedDraftCustomEmojiEntities(text: string): CustomEmojiTextEntity[];
  persistDraft(chatId: number): void;
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void;
  setDraftSelection(start: number, end: number): void;
  setDraftText(value: string): void;
  startReply(messageId: string, author: string, preview: string, isQuote?: boolean): void;
}

export function normalizedDraftCustomEmojiEntities(host: ChatDraftCoordinatorPort, text: string): CustomEmojiTextEntity[] {
    return normalizeCustomEmojiEntitiesForSubstring(
      host.composerDraftText,
      text,
      host.customEmojiDraftEntities
    );
  }

export function persistDraft(host: ChatDraftCoordinatorPort, chatId: number): void {
    // Leaving the chat mid-edit must not overwrite the server draft with
    // the edit buffer (same rule as scheduleDraftDebounce)
    const owner = host.accountStore;
    const lifecycleToken = host.pageLifecycleToken;
    const routeChatId = host.routeChatId;
    const activeChatId = host.activeChatId;
    // Back clears global navigation before disappear. Disappear increments
    // lifecycle before calling us: the page's
    // route/active chat, not either global field, still owns this closing draft.
    const ownedChatId = routeChatId !== 0 ? routeChatId : activeChatId;
    if (owner === undefined || chatId === 0 || chatId !== ownedChatId || host.isEditingMessage) {
      return;
    }
    const draftText = host.composerDraftText;
    const text = draftText.trim();
    const replyToMessageId = host.replyToMessageId;
    const normalizedEntities = normalizeCustomEmojiEntitiesForSubstring(draftText, text, host.customEmojiDraftEntities);
    try {
      const runtime = getAppCoreRuntime();
      if (runtime.getStore() !== owner) return;
      const chat = owner.getState().chats.chats.get(chatId);
      // A revoked AppStore scope reads empty state. Never recover this lookup
      // from the global account or send an old buffer through its new adapter.
      if (chat === undefined) return;
      const storedDraft = chat.draftText.trim();
      const storedReply = chat.draftReplyToMessageId;
      const storedEntities = chat.draftCustomEmojiEntities;
      // Empty text serializes as an explicit clear, so the reply id only
      // matters for the skip-check when there is text to keep
      if (text === storedDraft && customEmojiEntitiesEqual(normalizedEntities, storedEntities) &&
        (text.length === 0 || replyToMessageId === storedReply)) {
        return;
      }
      // The existing adapter captures a TDLib client generation. Acquire it
      // only for the verified owning scope, then recheck before dispatch.
      const gateway = getTdGatewayAdapter();
      if (owner !== host.accountStore || lifecycleToken !== host.pageLifecycleToken ||
        routeChatId !== host.routeChatId || activeChatId !== host.activeChatId ||
        runtime !== getAppCoreRuntime() || runtime.getStore() !== owner ||
        !owner.getState().chats.chats.has(chatId) || host.isEditingMessage ||
        draftText !== host.composerDraftText || replyToMessageId !== host.replyToMessageId ||
        !customEmojiEntitiesEqual(normalizedEntities, host.normalizedDraftCustomEmojiEntities(text))) return;
      gateway.send(createSetChatDraftCommand(chatId, text, replyToMessageId, normalizedEntities))
        .then((response: Object) => {
          const obj = response as TdObject;
          hilog.info(DOMAIN, TAG, 'Draft response: %{public}s', obj.getType());
        })
        .catch((error: Error) => {
          hilog.warn(DOMAIN, TAG, 'Draft send failed: %{public}s', error.message);
        });
      hilog.info(DOMAIN, TAG, 'Draft %{public}s for chat %{public}d',
        text.length > 0 ? 'saved' : 'cleared', chatId);
    } catch (_e) {
    }
  }

export function restoreDraftFromChat(host: ChatDraftCoordinatorPort): void {
    const owner = host.accountStore;
    const chatId = host.activeChatId;
    const lifecycle = host.pageLifecycleToken;
    if (owner === undefined || chatId === 0 || host.composerDraftText.length > 0 ||
      host.isEditingMessage || host.isForwardingMessages) {
      return;
    }
    try {
      const runtime = getAppCoreRuntime();
      if (runtime.getStore() !== owner) return;
      const state = owner.getState();
      const chat = state.chats.chats.get(chatId);
      if (owner !== host.accountStore || chatId !== host.activeChatId || lifecycle !== host.pageLifecycleToken ||
        getAppCoreRuntime() !== runtime || runtime.getStore() !== owner || host.composerDraftText.length > 0 ||
        host.isEditingMessage || host.isForwardingMessages) return;
      if (chat && chat.draftText.length > 0) {
        host.setCustomEmojiEntities(chat.draftCustomEmojiEntities);
        host.setDraftText(chat.draftText);
        host.setDraftSelection(chat.draftText.length, chat.draftText.length);
        // Telegram restores the reply target together with the draft text
        if (chat.draftReplyToMessageId !== '0' && host.replyToMessageId === '0') {
          const chatMessages = state.messages.messages.get(chatId);
          const target = chatMessages ? chatMessages.get(chat.draftReplyToMessageId) : undefined;
          const author = target ? resolveSenderName(target, state) : '';
          const preview = chatMessages
            ? resolveReplyPreview(chatMessages, chat.draftReplyToMessageId) : '';
          host.startReply(chat.draftReplyToMessageId, author, preview);
        }
        hilog.info(DOMAIN, TAG, 'Draft restored for chat %{public}d (reply %{public}s)',
          host.activeChatId, chat.draftReplyToMessageId);
      }
    } catch (_e) {
    }
  }

export function scheduleDraftDebounce(host: ChatDraftCoordinatorPort): void {
    // Edit mode reuses the composer for the message being edited — that text
    // is NOT the chat draft and must never be persisted as one
    if (host.isEditingMessage) {
      return;
    }
    if (host.draftDebounceTimerId >= 0) {
      clearTimeout(host.draftDebounceTimerId);
    }
    const lifecycleToken = host.pageLifecycleToken;
    host.draftDebounceTimerId = setTimeout(() => {
      host.draftDebounceTimerId = -1;
      if (lifecycleToken !== host.pageLifecycleToken) {
        return;
      }
      host.persistDraft(host.activeChatId);
    }, 1500);
  }
