// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppState, Chat } from '../../../core/model/AppState';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';
import { ChatAccessController } from './ChatAccessController';
import { ChatSlowmodeHost, ChatSlowmodeController } from './ChatSlowmodeController';
import { ChatAvatarPresentation, ChatSubtitlePresentation, chatAvatarPresentation, chatSubtitlePresentation } from './ChatTopBarPresentation';
import { loadSupergroupFullInfo, loadBasicGroupFullInfo } from '../../../domain/usecases/loadProfileInfo';

export interface ChatTopBarCoordinatorPort extends ChatSlowmodeHost {
  slowmodeController: ChatSlowmodeController;
  activeChatId: number;
  chatAccessController?: ChatAccessController;
  chatAccessUnavailable: boolean;
  chatAvatarColorIndex: number;
  chatAvatarImageSrc: string;
  chatAvatarInitials: string;
  chatBottomBarAction: 'none' | 'mute' | 'unmute' | 'join' | 'retry';
  chatBottomBarReason: 'restricted' | 'banned' | 'unknown' | '';
  chatBottomBarRestricted: boolean;
  chatIsOnline: boolean;
  chatSubtitle: string;
  chatSubtitleMode: TgChatTopBarSubtitleMode;
  chatSubtitleSpinner: boolean;
  chatTopBarTrailingAction: TgChatTopBarTrailingAction;
  composerAccessRetryVisible: boolean;
  memberCountHydratedChatId: number;
  applyChatAvatarPresentation(value: ChatAvatarPresentation): void;
  applyChatSubtitlePresentation(value: ChatSubtitlePresentation): void;
  deriveChatBottomBar(chat: Chat, state: AppState): void;
}

export function applyChatAvatarPresentation(host: ChatTopBarCoordinatorPort, value: ChatAvatarPresentation): void {
    host.chatAvatarInitials = value.initials;
    host.chatAvatarColorIndex = value.colorIndex;
    host.chatAvatarImageSrc = value.imageSrc;
    host.chatTopBarTrailingAction = value.trailingAction;
  }

export function applyChatSubtitlePresentation(host: ChatTopBarCoordinatorPort, value: ChatSubtitlePresentation): void {
    host.chatSubtitle = value.subtitle;
    host.chatSubtitleMode = value.mode;
    host.chatSubtitleSpinner = value.spinner;
    host.chatIsOnline = value.isOnline;
  }

export function updateChatTopBarData(host: ChatTopBarCoordinatorPort, state: AppState): void {
    const chat = state.chats.chats.get(host.activeChatId);
    if (chat === undefined) {
      host.slowmodeController.observe(host);
      host.chatBottomBarAction = 'none';
      host.chatBottomBarRestricted = true;
      host.chatBottomBarReason = 'unknown';
      host.chatAccessUnavailable = false;
      host.composerAccessRetryVisible = false;
      host.chatAccessController?.observe(new Chat());
      host.applyChatSubtitlePresentation(chatSubtitlePresentation(undefined, state,
        host.activeChatId, (): number => Date.now()));
      host.applyChatAvatarPresentation(chatAvatarPresentation(undefined));
      return;
    }

    host.chatAccessController?.observe(chat, chat.type === 'group' ? state.chats.basicGroupAccess.get(chat.basicGroupId) :
      state.chats.supergroupAccess.get(chat.supergroupId), state.chats.supergroupBoosts.get(chat.supergroupId),
      state.chats.supergroupSlowmode.get(chat.supergroupId));
    host.chatAccessUnavailable = host.chatAccessController?.isUnavailable() ?? false;
    host.applyChatAvatarPresentation(chatAvatarPresentation(chat));
    host.deriveChatBottomBar(chat, state);

    // Data hydration belongs to the page; the presentation mapper never starts requests.
    if (chat.peerUserId <= 0 && chat.memberCount === 0 && host.memberCountHydratedChatId !== chat.id) {
      if (chat.supergroupId > 0) {
        host.memberCountHydratedChatId = chat.id;
        loadSupergroupFullInfo(chat.id, chat.supergroupId);
      } else if (chat.basicGroupId > 0) {
        host.memberCountHydratedChatId = chat.id;
        loadBasicGroupFullInfo(chat.id, chat.basicGroupId);
      }
    }
    host.applyChatSubtitlePresentation(chatSubtitlePresentation(chat, state,
      host.activeChatId, (): number => Date.now()));
  }
