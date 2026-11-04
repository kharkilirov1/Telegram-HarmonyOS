// Route contract for TgChatInvitePage (S14c).
// Reached from an external t.me/+... or t.me/joinchat/... link; the page pops with the joined chat so
// MainTabsPage can hydrate it and open the chat screen.

import { ChatDto } from '../../../core/model/dto/ChatDto';

export class ChatInviteRouteParams {
  inviteLink: string = '';
}

export class ChatInviteJoinResult {
  chat: ChatDto = new ChatDto();

  constructor(chat: ChatDto) {
    this.chat = chat;
  }
}
