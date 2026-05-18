export class ChatScreenRouteParams {
  chatId: number = 0;
  chatTitle: string = '';

  constructor(chatId: number, chatTitle: string = '') {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
  }
}
