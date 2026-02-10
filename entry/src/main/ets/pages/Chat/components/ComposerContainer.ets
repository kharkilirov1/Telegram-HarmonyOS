import { ChatInputBar } from '../../../components/Chat/ChatInputBar';
import { Message } from '../../../models/Message';

@ComponentV2
export struct ComposerContainer {
  @Param chatId: number = 0;
  @Param replyMessage: Message | null = null;
  @Param editMessage: Message | null = null;

  @Event onSendMessage: (text: string) => void = () => {};
  @Event onSendScheduled: (text: string, sendDate: number) => void = () => {};
  @Event onEditMessage: (messageId: number, text: string) => void = () => {};
  @Event onCancelReply: () => void = () => {};
  @Event onCancelEdit: () => void = () => {};
  @Event onSendSticker: (emoji: string) => void = () => {};
  @Event onSendGif: (gifId: number) => void = () => {};
  @Event onSendVoice: (duration: number) => void = () => {};
  @Event onDraftChange: (text: string) => void = () => {};
  @Event onCreatePoll: () => void = () => {};

  build() {
    ChatInputBar({
      replyMessage: this.replyMessage,
      editMessage: this.editMessage,
      chatId: this.chatId,
      onSendMessage: (text: string) => { this.onSendMessage(text); },
      onSendScheduled: (text: string, sendDate: number) => { this.onSendScheduled(text, sendDate); },
      onEditMessage: (messageId: number, text: string) => { this.onEditMessage(messageId, text); },
      onCancelReply: () => { this.onCancelReply(); },
      onCancelEdit: () => { this.onCancelEdit(); },
      onSendSticker: (emoji: string) => { this.onSendSticker(emoji); },
      onSendGif: (gifId: number) => { this.onSendGif(gifId); },
      onSendVoice: (duration: number) => { this.onSendVoice(duration); },
      onDraftChange: (text: string) => { this.onDraftChange(text); },
      onCreatePoll: () => { this.onCreatePoll(); }
    })
  }
}
