// Route contract for TgChatAdminRightsPage (G6).

export class ChatAdminRightsRouteParams {
  chatId: number = 0;
  userId: number = 0;

  constructor(chatId: number, userId: number) {
    this.chatId = chatId;
    this.userId = userId;
  }
}
