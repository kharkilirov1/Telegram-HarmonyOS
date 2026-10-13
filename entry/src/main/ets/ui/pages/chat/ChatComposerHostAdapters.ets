// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppStore } from '../../../core/store/AppStore';
import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';
import { SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';

export interface ChatComposerHostAdaptersPort {
  accountStore?: AppStore;
  activeChatId: number;
  composerCaretRequestRevision: number;
  composerInputRevision: number;
  composerDraftText: string;
  composerSelectionEnd: number;
  composerSelectionStart: number;
  customEmojiDraftEntities: CustomEmojiTextEntity[];
  expectedProgrammaticCustomEmojiText: string;
  isEditingMessage: boolean;
  isForwardingMessages: boolean;
  isSending: boolean;
  pageLifecycleToken: number;
  pendingAttachmentKind: string;
  pendingAttachmentPreview: string;
  pendingAttachmentTitle: string;
  pendingAttachmentUris: string[];
  replyToAuthor: string;
  replyToIsQuote: boolean;
  replyToMessageId: string;
  replyToPreview: string;
  sendMediaUseCase?: SendMediaMessageUseCase;
  sendUseCase?: SendMessageUseCase;
  sendingMessageOperation: number;
  showComposerEmojiPanel: boolean;
  voiceRecordingDurationMs: number;
  voiceRecordingState: TgVoiceRecordingState;
  canSendNewMessages(sendKind?: string): boolean;
  canUseComposer(isEditing: boolean, sendKind?: string): boolean;
  handleEditMessage(newText: string): void;
  handleForwardMessages(commentText: string): void;
  loadCustomEmojiPanelIfNeeded(): void;
  resetEmojiSearchState(): void;
  setStickerPanelVisible(value: boolean): void;
  getUIContext(): UIContext;
}

export function getActiveChatId(host: ChatComposerHostAdaptersPort): number {
    return host.activeChatId;
  }

export function getLifecycleToken(host: ChatComposerHostAdaptersPort): number {
    return host.pageLifecycleToken;
  }

export function getChatUIContext(host: ChatComposerHostAdaptersPort): UIContext {
    return host.getUIContext();
  }

export function getSendUseCase(host: ChatComposerHostAdaptersPort): SendMessageUseCase | undefined {
    return !host.isEditingMessage && host.canUseComposer(false, 'text') ? host.sendUseCase : undefined;
  }

export function getSendMediaUseCase(host: ChatComposerHostAdaptersPort, mediaKind: string = ''): SendMediaMessageUseCase | undefined {
    if (mediaKind !== '' && mediaKind !== 'photo' && mediaKind !== 'video' &&
      mediaKind !== 'document' && mediaKind !== 'voice') return undefined;
    return !host.isEditingMessage && host.canUseComposer(false, mediaKind || 'media') ? host.sendMediaUseCase : undefined;
  }

export function setVoiceRecordingState(host: ChatComposerHostAdaptersPort, state: TgVoiceRecordingState, durationMs: number): void {
    host.voiceRecordingState = state;
    host.voiceRecordingDurationMs = durationMs;
  }

export function isSendingMessage(host: ChatComposerHostAdaptersPort): boolean {
    return host.isSending;
  }

export function setSendingMessage(host: ChatComposerHostAdaptersPort, value: boolean): void {
    // Text/media and forwarding share one busy owner. Explicit reset also
    // retires old completion callbacks, even after a same-chat round trip.
    host.sendingMessageOperation++;
    host.isSending = value;
  }

export function getSendOperationToken(host: ChatComposerHostAdaptersPort): number {
    return host.sendingMessageOperation;
  }

export function hasActiveChatState(host: ChatComposerHostAdaptersPort): boolean {
    return host.accountStore?.getState().chats.chats.has(host.activeChatId) === true;
  }

export function isEditModeActive(host: ChatComposerHostAdaptersPort): boolean {
    return host.isEditingMessage;
  }

export function isForwardModeActive(host: ChatComposerHostAdaptersPort): boolean {
    return host.isForwardingMessages;
  }

export function submitEditMessage(host: ChatComposerHostAdaptersPort, text: string): void {
    host.handleEditMessage(text);
  }

export function submitForwardMessages(host: ChatComposerHostAdaptersPort, commentText: string): void {
    host.handleForwardMessages(commentText);
  }

export function getComposerInputRevision(host: ChatComposerHostAdaptersPort): number {
  return host.composerInputRevision;
}

export function getDraftText(host: ChatComposerHostAdaptersPort): string {
    return host.composerDraftText;
  }

export function setDraftText(host: ChatComposerHostAdaptersPort, value: string): void {
    if (value.length === 0) {
      host.customEmojiDraftEntities = [];
    }
    if (host.customEmojiDraftEntities.length > 0) {
      host.expectedProgrammaticCustomEmojiText = value;
    } else {
      host.expectedProgrammaticCustomEmojiText = '';
    }
    host.composerDraftText = value;
  }

export function getDraftSelectionStart(host: ChatComposerHostAdaptersPort): number {
    return host.composerSelectionStart;
  }

export function getDraftSelectionEnd(host: ChatComposerHostAdaptersPort): number {
    return host.composerSelectionEnd;
  }

export function setDraftSelection(host: ChatComposerHostAdaptersPort, start: number, end: number): void {
    host.composerSelectionStart = Math.max(0, Math.min(host.composerDraftText.length, start));
    host.composerSelectionEnd = Math.max(0, Math.min(host.composerDraftText.length, end));
    host.composerCaretRequestRevision++;
  }

export function getCustomEmojiEntities(host: ChatComposerHostAdaptersPort): CustomEmojiTextEntity[] {
    return host.customEmojiDraftEntities;
  }

export function setCustomEmojiEntities(host: ChatComposerHostAdaptersPort, value: CustomEmojiTextEntity[]): void {
    host.customEmojiDraftEntities = value.slice();
  }

export function setEmojiPanelVisible(host: ChatComposerHostAdaptersPort, value: boolean): void {
    host.showComposerEmojiPanel = value;
    if (value) {
      host.setStickerPanelVisible(false);
      host.loadCustomEmojiPanelIfNeeded();
    } else {
      host.resetEmojiSearchState();
    }
  }

export function getEmojiPanelVisible(host: ChatComposerHostAdaptersPort): boolean {
    return host.showComposerEmojiPanel;
  }

export function getReplyToMessageId(host: ChatComposerHostAdaptersPort): string {
    return host.replyToMessageId;
  }

export function setReplyMode(host: ChatComposerHostAdaptersPort, messageId: string, author: string, preview: string, isQuote: boolean): void {
    host.replyToMessageId = messageId;
    host.replyToAuthor = author;
    host.replyToPreview = preview;
    host.replyToIsQuote = isQuote;
  }

export function clearReplyMode(host: ChatComposerHostAdaptersPort): void {
    host.replyToMessageId = '0';
    host.replyToAuthor = '';
    host.replyToPreview = '';
    host.replyToIsQuote = false;
  }

export function getPendingAttachmentUris(host: ChatComposerHostAdaptersPort): string[] {
    return host.pendingAttachmentUris;
  }

export function getPendingAttachmentKind(host: ChatComposerHostAdaptersPort): string {
    return host.pendingAttachmentKind;
  }

export function setPendingAttachmentState(host: ChatComposerHostAdaptersPort, kind: string, title: string, preview: string, uris: string[]): void {
    host.pendingAttachmentKind = kind;
    host.pendingAttachmentTitle = title;
    host.pendingAttachmentPreview = preview;
    host.pendingAttachmentUris = uris;
  }

export function clearPendingAttachmentState(host: ChatComposerHostAdaptersPort): void {
    host.pendingAttachmentKind = '';
    host.pendingAttachmentTitle = '';
    host.pendingAttachmentPreview = '';
    host.pendingAttachmentUris = [];
  }
