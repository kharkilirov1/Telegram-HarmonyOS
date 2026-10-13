// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppState, Chat } from '../../../core/model/AppState';
import { AppStore } from '../../../core/store/AppStore';
import { selectChatInputPanel, needsSupergroupBoosts } from './ChatInputPanelPolicy';
import { ChatAccessController } from './ChatAccessController';
import { SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { SetChatMuteUseCase, MUTE_FOREVER } from '../../../domain/usecases/setChatMute';
import { JoinChatUseCase } from '../../../domain/usecases/joinChat';
import { localized } from '../../../core/utils/AppResource';
import { ChatSlowmodeHost, ChatSlowmodeController, currentSlowmodeSeconds } from './ChatSlowmodeController';

export interface ChatPermissionCoordinatorPort extends ChatSlowmodeHost {
  accountStore?: AppStore;
  pageLifecycleToken: number;
  composerSlowmodeSeconds: number;
  slowmodeController: ChatSlowmodeController;
  activeChatId: number;
  chatAccessController?: ChatAccessController;
  chatAccessUnavailable: boolean;
  chatBottomBarAction: 'none' | 'mute' | 'unmute' | 'join' | 'retry';
  chatBottomBarReason: 'restricted' | 'banned' | 'unknown' | '';
  chatBottomBarRestricted: boolean;
  chatJoinUseCase?: JoinChatUseCase;
  chatMuteUseCase?: SetChatMuteUseCase;
  composerAccessRetryVisible: boolean;
  composerAllowedKinds: string[];
  composerDraftText: string;
  editingMessageId: string;
  isEditingMessage: boolean;
  isForwardingMessages: boolean;
  pendingAttachmentKind: string;
  pendingAttachmentUris: string[];
  canUseComposer(isEditing: boolean, sendKind?: string): boolean;
  deriveChatBottomBar(chat: Chat, state: AppState): void;
  getForwardUseCase(sourceChatId?: number, messageIds?: string[]): ForwardMessagesUseCase | undefined;
  getSendMediaUseCase(mediaKind?: string): SendMediaMessageUseCase | undefined;
  getSendUseCase(): SendMessageUseCase | undefined;
}

export function refreshChatInputPanel(host: ChatPermissionCoordinatorPort): void {
    host.slowmodeController.observe(host);
    const state = host.accountStore?.getState();
    const chat = state?.chats.chats.get(host.activeChatId);
    if (state && chat) host.deriveChatBottomBar(chat, state);
  }

export function canUseComposer(host: ChatPermissionCoordinatorPort, isEditing: boolean, sendKind: string = ''): boolean {
    const state = host.accountStore?.getState();
    const chat = state?.chats.chats.get(host.activeChatId);
    return state !== undefined && chat !== undefined &&
      selectChatInputPanel(chat, chat.type === 'group' ? state.chats.basicGroupAccess.get(chat.basicGroupId) :
        state.chats.supergroupAccess.get(chat.supergroupId), isEditing, sendKind, state.chats.supergroupBoosts.get(chat.supergroupId)) === 'composer';
  }

export function canSendNewMessages(host: ChatPermissionCoordinatorPort, sendKind: string = ''): boolean {
    const state = host.accountStore?.getState();
    return !host.isEditingMessage && host.canUseComposer(false, sendKind) && state !== undefined &&
      currentSlowmodeSeconds(state, host.activeChatId) === 0;
  }

export function composerCanSubmit(host: ChatPermissionCoordinatorPort): boolean {
    if (host.isEditingMessage) return host.canUseComposer(true);
    if (!canSendNewMessages(host)) return false;
    if (host.composerAllowedKinds.length === 0) return false;
    if (host.pendingAttachmentUris.length > 0) return host.getSendMediaUseCase(host.pendingAttachmentKind) !== undefined;
    if (host.isForwardingMessages) return host.getForwardUseCase() !== undefined &&
      (host.composerDraftText.trim().length === 0 || host.getSendUseCase() !== undefined);
    return host.getSendUseCase() !== undefined;
  }

export function composerAllows(host: ChatPermissionCoordinatorPort, kind: string): boolean {
    if (host.isEditingMessage) return false;
    if (kind === 'attachment') return host.composerAllowedKinds.indexOf('photo') >= 0 ||
      host.composerAllowedKinds.indexOf('video') >= 0 || host.composerAllowedKinds.indexOf('document') >= 0;
    return host.composerAllowedKinds.indexOf(kind) >= 0;
  }

export function deriveChatBottomBar(host: ChatPermissionCoordinatorPort, chat: Chat, state: AppState): void {
    host.slowmodeController.observe(host);
    const groupId = chat.type === 'group' ? chat.basicGroupId : chat.supergroupId;
    const access = chat.type === 'group' ? state.chats.basicGroupAccess.get(groupId) : state.chats.supergroupAccess.get(groupId);
    const boosts = state.chats.supergroupBoosts.get(groupId);
    const panel = selectChatInputPanel(chat, access, host.editingMessageId !== '0', '', boosts);
    const kinds: string[] = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
    const allowed: string[] = [];
    for (let i = 0; i < kinds.length; i++) {
      if (selectChatInputPanel(chat, access, false, kinds[i], boosts) === 'composer') allowed.push(kinds[i]);
    }
    // Store objects are not ArkUI state. Publish an explicit @Local snapshot so
    // per-kind @Param flags refresh even when the overall panel remains composer.
    // Dispatch guards still reread the scoped store rather than trusting this UI snapshot.
    host.composerAllowedKinds = allowed;
    host.composerAccessRetryVisible = panel === 'composer' && host.chatAccessUnavailable &&
      (needsSupergroupBoosts(chat, access, boosts) ||
        (chat.type === 'supergroup' && access?.isSlowModeEnabled === true &&
          state.chats.supergroupSlowmode.get(groupId) === undefined));
    host.chatBottomBarRestricted = panel === 'restricted' || panel === 'banned' || panel === 'unknown';
    host.chatBottomBarReason = host.chatBottomBarRestricted ? panel as 'restricted' | 'banned' | 'unknown' : '';
    host.chatBottomBarAction = 'none';
    if (panel === 'mute' || panel === 'unmute' || panel === 'join') host.chatBottomBarAction = panel;
    if (panel === 'unknown' && host.chatAccessUnavailable && Number.isSafeInteger(chat.id) && chat.id !== 0 &&
      Number.isSafeInteger(groupId) && groupId > 0) {
      host.chatBottomBarRestricted = false;
      host.chatBottomBarReason = '';
      host.chatBottomBarAction = 'retry';
    }
  }

export function bottomBarActionLabel(host: ChatPermissionCoordinatorPort): string {
    switch (host.chatBottomBarAction) {
      case 'retry':
        return localized($r('app.string.retry').id, 'Retry');
      case 'join':
        return localized($r('app.string.channel_join').id, 'Join');
      case 'unmute':
        return localized($r('app.string.unmute').id, 'Unmute');
      case 'mute':
        return localized($r('app.string.mute').id, 'Mute');
      default:
        return '';
    }
  }

export function retryChatAccess(host: ChatPermissionCoordinatorPort): void {
    if (host.composerAccessRetryVisible) host.chatAccessController?.retry();
  }

export function bottomBarMessage(host: ChatPermissionCoordinatorPort): string {
    if (host.chatBottomBarReason === 'banned' ||
      (host.chatBottomBarReason === 'unknown' && host.chatAccessUnavailable)) {
      const chat = host.accountStore?.getState().chats.chats.get(host.activeChatId);
      return chat?.type === 'group'
        ? localized($r('app.string.group_access_unavailable').id, 'This group is unavailable.')
        : localized($r('app.string.channel_access_unavailable').id, 'This channel is unavailable.');
    }
    if (host.chatBottomBarReason === 'unknown') return localized($r('app.string.loading').id, 'Loading...');
    return localized($r('app.string.conversation_default_restricted_text').id,
      "Writing messages isn't allowed in this group.");
  }

export function handleChatBottomBarAction(host: ChatPermissionCoordinatorPort): void {
    if (host.activeChatId === 0 || host.chatBottomBarAction === 'none') {
      return;
    }
    // Use cases throw AppError on TDLib failures (flood limits, invite-only
    // channels) — the rejection must be handled, the store update drives the
    // next derive pass on success.
    const muteUseCase = host.chatMuteUseCase;
    const joinUseCase = host.chatJoinUseCase;
    if (host.chatBottomBarAction === 'retry') {
      host.chatAccessController?.retry();
    } else if (host.chatBottomBarAction === 'mute' && muteUseCase !== undefined) {
      muteUseCase.mute(host.activeChatId, MUTE_FOREVER).catch((): void => {});
    } else if (host.chatBottomBarAction === 'unmute' && muteUseCase !== undefined) {
      muteUseCase.unmute(host.activeChatId).catch((): void => {});
    } else if (host.chatBottomBarAction === 'join' && joinUseCase !== undefined) {
      joinUseCase.join(host.activeChatId).catch((): void => {});
    }
  }
