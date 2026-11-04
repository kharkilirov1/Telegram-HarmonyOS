// Admin navigation helpers for the chat page (keeps TgChatScreenPage within the bounded-owner limit).
// Every entry pushes the same route the corresponding screen registered in route_map.json.

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { ProfileMembersRouteParams } from '../profile/TgProfileMembersPage';
import { ChatInviteLinksRouteParams } from './chatInviteLinksRoute';
import { ChatAdministratorsRouteParams } from './chatAdministratorsRoute';
import { ChatPermissionsRouteParams } from './chatPermissionsRoute';
import { ChatAutoDeleteRouteParams } from './chatAutoDeleteRoute';
import { ChatScheduledMessagesRouteParams } from './chatScheduledMessagesRoute';
import { MessageThreadRouteParams } from './messageThreadRoute';

export function currentAccountUserId(): number {
  try {
    return getAppCoreRuntime().getStore().getState().auth.userId;
  } catch (_error) {
    return 0;
  }
}

export function openMembersScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  const chat = getAppCoreRuntime().getStore().getState().chats.chats.get(chatId);
  stack.pushPathByName('TgProfileMembersPage', new ProfileMembersRouteParams(chatId,
    chat?.supergroupId ?? 0, 'all', chat?.memberCount ?? 0));
  return true;
}

export function openInviteLinksScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  stack.pushPathByName('TgChatInviteLinksPage', new ChatInviteLinksRouteParams(chatId));
  return true;
}

export function openAdministratorsScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  stack.pushPathByName('TgChatAdministratorsPage', new ChatAdministratorsRouteParams(chatId));
  return true;
}

export function openScheduledScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  stack.pushPathByName('TgChatScheduledMessagesPage', new ChatScheduledMessagesRouteParams(chatId));
  return true;
}

export function openAutoDeleteScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  stack.pushPathByName('TgChatAutoDeletePage', new ChatAutoDeleteRouteParams(chatId));
  return true;
}

export function openPermissionsScreen(stack: NavPathStack | undefined, chatId: number): boolean {
  if (stack === undefined) {
    return false;
  }
  stack.pushPathByName('TgChatPermissionsPage', new ChatPermissionsRouteParams(chatId));
  return true;
}

// D11: open the comment thread of a channel post.
export function openMessageThread(stack: NavPathStack | undefined, chatId: number, messageId: string,
  title: string, replyCount: number): boolean {
  if (stack === undefined || chatId <= 0 || messageId === '0') {
    return false;
  }
  stack.pushPathByName('TgMessageThreadPage', new MessageThreadRouteParams(chatId, messageId, title, replyCount));
  return true;
}
