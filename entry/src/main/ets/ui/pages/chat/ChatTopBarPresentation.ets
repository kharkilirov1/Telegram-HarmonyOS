// Pure header derivation. Route ownership, access observation and @Local publication stay in the page.

import { fileUri } from '@kit.CoreFileKit';
import { AppState, Chat } from '../../../core/model/AppState';
import { localized, localizedPlural } from '../../../core/utils/AppResource';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';

export class ChatAvatarPresentation {
  initials: string = '';
  colorIndex: number = 0;
  imageSrc: string = '';
  trailingAction: TgChatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
}

export class ChatSubtitlePresentation {
  subtitle: string = '';
  mode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  spinner: boolean = false;
  isOnline: boolean = false;
}

function computeInitials(title: string): string {
  const trimmed = title.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const parts = trimmed.split(' ');
  if (parts.length >= 2 && parts[1].length > 0) {
    return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
  }
  return trimmed.charAt(0).toUpperCase();
}

function formatUserStatus(status: string): string {
  if (status === 'online') {
    return localized($r('app.string.online').id, 'online');
  }
  if (status === 'recently') {
    return localized($r('app.string.last_seen_recently').id, 'last seen recently');
  }
  if (status === 'lastWeek') {
    return localized($r('app.string.last_seen_within_week').id, 'last seen within a week');
  }
  if (status === 'lastMonth') {
    return localized($r('app.string.last_seen_within_month').id, 'last seen within a month');
  }
  if (status === 'longTimeAgo') {
    return localized($r('app.string.last_seen_long_ago').id, 'last seen a long time ago');
  }
  return '';
}

function formatTypingSubtitle(actionType: string, subjectName: string = ''): string {
  let actionLabel: string = '';
  switch (actionType) {
    case 'typing':
      actionLabel = localized($r('app.string.typing').id, 'typing...');
      break;
    case 'recordingVideo':
      actionLabel = localized($r('app.string.chat_preview_recording_video').id, 'recording video...');
      break;
    case 'uploadingVideo':
      actionLabel = localized($r('app.string.chat_preview_sending_video').id, 'sending video...');
      break;
    case 'recordingVoice':
      actionLabel = localized($r('app.string.chat_preview_recording_voice').id, 'recording voice...');
      break;
    case 'uploadingVoice':
      actionLabel = localized($r('app.string.chat_preview_sending_voice').id, 'sending voice...');
      break;
    case 'uploadingPhoto':
      actionLabel = localized($r('app.string.chat_preview_sending_photo').id, 'sending photo...');
      break;
    case 'uploadingDocument':
      actionLabel = localized($r('app.string.chat_preview_sending_file').id, 'sending file...');
      break;
    case 'choosingSticker':
      actionLabel = localized($r('app.string.chat_preview_choosing_sticker').id, 'choosing sticker...');
      break;
    case 'choosingLocation':
      actionLabel = localized($r('app.string.chat_preview_choosing_location').id, 'choosing location...');
      break;
    case 'choosingContact':
      actionLabel = localized($r('app.string.chat_preview_choosing_contact').id, 'choosing contact...');
      break;
    case 'playingGame':
      actionLabel = localized($r('app.string.chat_preview_playing_game').id, 'playing game...');
      break;
    case 'recordingVideoNote':
      actionLabel = localized($r('app.string.chat_preview_recording_video_note').id, 'recording video message...');
      break;
    case 'uploadingVideoNote':
      actionLabel = localized($r('app.string.chat_preview_sending_video_note').id, 'sending video message...');
      break;
    default:
      actionLabel = localized($r('app.string.typing').id, 'typing...');
      break;
  }
  return subjectName.length > 0 ? `${subjectName} ${actionLabel}` : actionLabel;
}

function formatConnectionSubtitle(status: string): string {
  switch (status) {
    case 'connecting':
      return localized($r('app.string.call_connecting').id, 'Connecting...');
    case 'updating':
      return localized($r('app.string.connection_updating').id, 'Updating...');
    case 'waitingForNetwork':
      return localized($r('app.string.connection_waiting_network').id, 'Waiting for network...');
    default:
      return '';
  }
}

export function chatAvatarPresentation(chat: Chat | undefined): ChatAvatarPresentation {
  const result = new ChatAvatarPresentation();
  if (chat === undefined) {
    return result;
  }
  result.initials = computeInitials(chat.title);
  const colorSeed = chat.peerUserId > 0 ? chat.peerUserId : chat.id;
  result.colorIndex = colorSeed % 8;
  result.imageSrc = chat.photoSmall.length > 0 ? fileUri.getUriFromPath(chat.photoSmall) : '';
  result.trailingAction = chat.peerUserId > 0
    ? TgChatTopBarTrailingAction.Search : TgChatTopBarTrailingAction.Avatar;
  return result;
}

export function chatSubtitlePresentation(chat: Chat | undefined, state: AppState,
  chatId: number, now: () => number): ChatSubtitlePresentation {
  const result = new ChatSubtitlePresentation();
  if (chat === undefined) {
    return result;
  }
  if (chat.peerUserId > 0) {
    const user = state.users.users.get(chat.peerUserId);
    if (user !== undefined) {
      if (user.isBot) {
        result.subtitle = localized($r('app.string.member_role_bot').id, 'bot');
      } else {
        result.subtitle = formatUserStatus(user.status);
        result.mode = user.status === 'online'
          ? TgChatTopBarSubtitleMode.Online : TgChatTopBarSubtitleMode.Secondary;
        result.isOnline = user.status === 'online';
      }
    }
  } else if (chat.memberCount > 0) {
    result.subtitle = chat.type === 'channel'
      ? localizedPlural($r('app.plural.subscribers_count_plural').id,
        chat.memberCount, `${chat.memberCount} subscribers`)
      : localizedPlural($r('app.plural.group_members_count_plural').id,
        chat.memberCount, `${chat.memberCount} members`);
  } else {
    result.subtitle = chat.type === 'channel'
      ? localized($r('app.string.channel_label').id, 'channel')
      : localized($r('app.string.group_label').id, 'group');
  }

  const typingInfo = state.chats.typingActions.get(chatId);
  if (typingInfo && (now() - typingInfo.timestamp) < 6000) {
    let actorName: string = '';
    if (chat.peerUserId <= 0 && typingInfo.senderUserId > 0) {
      const sender = state.users.users.get(typingInfo.senderUserId);
      actorName = sender
        ? (sender.firstName.length > 0 ? sender.firstName : sender.username)
        : '';
    }
    result.subtitle = formatTypingSubtitle(typingInfo.actionType, actorName);
    result.mode = TgChatTopBarSubtitleMode.Activity;
  }

  if (state.connection.status !== 'ready') {
    result.subtitle = formatConnectionSubtitle(state.connection.status);
    result.mode = TgChatTopBarSubtitleMode.Activity;
    result.spinner = true;
  }
  return result;
}
