// Route contract for TgChatRestrictRightsPage (G6).

export class ChatRestrictRightsRouteParams {
  chatId: number = 0;
  userId: number = 0;

  constructor(chatId: number, userId: number) {
    this.chatId = chatId;
    this.userId = userId;
  }
}
