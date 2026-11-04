// Route params for the comment thread page (D11).
export class MessageThreadRouteParams {
  chatId: number = 0;
  messageId: string = '0';
  title: string = '';
  replyCount: number = 0;

  constructor(chatId: number = 0, messageId: string = '0', title: string = '', replyCount: number = 0) {
    this.chatId = chatId;
    this.messageId = messageId;
    this.title = title;
    this.replyCount = replyCount;
  }
}
