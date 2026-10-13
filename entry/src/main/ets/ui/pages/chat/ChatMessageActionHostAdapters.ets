// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppStore } from '../../../core/store/AppStore';
import { ChatForwardModeState } from './ChatMessageActionsController';
import { EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { PinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';

export interface ChatMessageActionHostAdaptersPort {
  accountStore?: AppStore;
  activeChatId: number;
  composerDraftText: string;
  customEmojiDraftEntities: CustomEmojiTextEntity[];
  deleteUseCase?: DeleteMessagesUseCase;
  draftDebounceTimerId: number;
  editUseCase?: EditMessageUseCase;
  editingAllowsEmpty: boolean;
  editingMessageId: string;
  editingOriginalText: string;
  expectedProgrammaticCustomEmojiText: string;
  forwardPreview: string;
  forwardSourceChatId: number;
  forwardTitle: string;
  forwardUseCase?: ForwardMessagesUseCase;
  forwardingMessageIds: string[];
  isEditingMessage: boolean;
  isForwardingMessages: boolean;
  pinUseCase?: PinChatMessageUseCase;
  canSendNewMessages(sendKind?: string): boolean;
  canUseComposer(isEditing: boolean, sendKind?: string): boolean;
  hasActiveChatState(): boolean;
  loadPinnedMessage(): void;
  refreshChatInputPanel(): void;
  setDraftSelection(start: number, end: number): void;
  setStickerPanelVisible(value: boolean): void;
}

export function getEditUseCase(host: ChatMessageActionHostAdaptersPort): EditMessageUseCase | undefined {
    return host.canUseComposer(true) ? host.editUseCase : undefined;
  }

export function getDeleteUseCase(host: ChatMessageActionHostAdaptersPort): DeleteMessagesUseCase | undefined {
    return host.deleteUseCase;
  }

export function getSourceForwardUseCase(host: ChatMessageActionHostAdaptersPort): ForwardMessagesUseCase | undefined {
    // Reading/copying a source does not require permission to send into that chat.
    return host.hasActiveChatState() ? host.forwardUseCase : undefined;
  }

export function getForwardUseCase(host: ChatMessageActionHostAdaptersPort, sourceChatId: number = host.forwardSourceChatId,
    messageIds: string[] = host.forwardingMessageIds): ForwardMessagesUseCase | undefined {
    if (host.isEditingMessage || !host.canUseComposer(false)) return undefined;
    const state = host.accountStore?.getState();
    const targetType = state?.chats.chats.get(host.activeChatId)?.type;
    if (targetType !== 'group' && targetType !== 'supergroup') return host.forwardUseCase;
    const allKinds = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
    // Unknown source metadata is safe only when every possible kind is allowed.
    // The captured IDs also work after the forward preview has been cleared.
    for (let i = 0; i < messageIds.length; i++) {
      const message = state?.messages.messages.get(sourceChatId)?.get(messageIds[i]) ??
        state?.messages.associatedMessages.get(sourceChatId)?.get(messageIds[i]);
      let kind: string = message?.content.type ?? 'unknown';
      if (kind === 'contact' || kind === 'location') kind = 'text';
      if (kind === 'animation' || kind === 'sticker') kind = 'other';
      if (allKinds.indexOf(kind) < 0) {
        for (let k = 0; k < allKinds.length; k++) {
          if (!host.canUseComposer(false, allKinds[k])) return undefined;
        }
      } else if (!host.canUseComposer(false, kind)) return undefined;
    }
    if (messageIds.length === 0) {
      for (let k = 0; k < allKinds.length; k++) {
        if (!host.canUseComposer(false, allKinds[k])) return undefined;
      }
    }
    return host.forwardUseCase;
  }

export function getPinUseCase(host: ChatMessageActionHostAdaptersPort): PinChatMessageUseCase | undefined {
    return host.pinUseCase;
  }

export function onPinnedMessageChanged(host: ChatMessageActionHostAdaptersPort): void {
    host.loadPinnedMessage();
  }

export function setEditMode(host: ChatMessageActionHostAdaptersPort, messageId: string, originalText: string, allowEmptyEdit: boolean = false): void {
    host.isEditingMessage = true;
    host.editingMessageId = messageId;
    host.editingOriginalText = originalText;
    host.editingAllowsEmpty = allowEmptyEdit;
    host.customEmojiDraftEntities = [];
    host.expectedProgrammaticCustomEmojiText = '';
    // Telegram semantics: the composer is prefilled with the current text
    host.composerDraftText = originalText;
    host.setDraftSelection(originalText.length, originalText.length);
    host.setStickerPanelVisible(false);
    host.refreshChatInputPanel();
  }

export function getEditingMessageId(host: ChatMessageActionHostAdaptersPort): string {
    return host.editingMessageId;
  }

export function getEditingOriginalText(host: ChatMessageActionHostAdaptersPort): string {
    return host.editingOriginalText;
  }

export function rebaseEditingMessage(host: ChatMessageActionHostAdaptersPort, messageId: string, text: string): void {
    host.editingMessageId = messageId;
    host.editingOriginalText = text;
  }

export function clearEditMode(host: ChatMessageActionHostAdaptersPort, clearDraft: boolean): void {
    host.isEditingMessage = false;
    host.editingMessageId = '0';
    host.editingOriginalText = '';
    host.editingAllowsEmpty = false;
    if (clearDraft) {
      host.composerDraftText = '';
      host.customEmojiDraftEntities = [];
      host.expectedProgrammaticCustomEmojiText = '';
      host.setDraftSelection(0, 0);
      // Kill any pending debounce so the programmatic text reset cannot
      // fire a stray setChatDraftMessage clear after the edit submits
      if (host.draftDebounceTimerId >= 0) {
        clearTimeout(host.draftDebounceTimerId);
        host.draftDebounceTimerId = -1;
      }
    }
    host.refreshChatInputPanel();
  }

export function setForwardMode(host: ChatMessageActionHostAdaptersPort, messageIds: string[], sourceChatId: number, title: string, preview: string): void {
    host.isForwardingMessages = true;
    host.forwardingMessageIds = [...messageIds];
    host.forwardSourceChatId = sourceChatId;
    host.forwardTitle = title;
    host.forwardPreview = preview;
  }

export function getForwardModeState(host: ChatMessageActionHostAdaptersPort): ChatForwardModeState {
    const state = new ChatForwardModeState();
    state.isForwardingMessages = host.isForwardingMessages;
    state.messageIds = [...host.forwardingMessageIds];
    state.sourceChatId = host.forwardSourceChatId;
    state.title = host.forwardTitle;
    state.preview = host.forwardPreview;
    return state;
  }

export function clearForwardMode(host: ChatMessageActionHostAdaptersPort): void {
    host.isForwardingMessages = false;
    host.forwardingMessageIds = [];
    host.forwardSourceChatId = 0;
    host.forwardTitle = '';
    host.forwardPreview = '';
  }
