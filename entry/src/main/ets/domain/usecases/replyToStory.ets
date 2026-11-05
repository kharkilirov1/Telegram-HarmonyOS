// I6: replying to a story sends a normal message into the author's chat with a story reply target, so the
// existing send pipeline is reused and only the reply object differs.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSendMessageCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00B6;
const TAG = 'ReplyToStory';
export const STORY_REPLY_MAX_LENGTH = 4096;

export class ReplyToStoryUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  validate(text: string): string {
    if (text.trim().length === 0) {
      return 'Write a reply first';
    }
    if (text.length > STORY_REPLY_MAX_LENGTH) {
      return 'The reply is too long';
    }
    return '';
  }

  // storyAuthorChatId is the chat the story belongs to; TDLib replies in that chat.
  async execute(storyAuthorChatId: number, storyId: number, text: string): Promise<boolean> {
    if (storyAuthorChatId === 0 || storyId <= 0 || this.validate(text).length > 0) {
      return false;
    }
    try {
      const command = createSendMessageCommand(storyAuthorChatId, text);
      command.payload.replyToStoryPosterChatId = storyAuthorChatId;
      command.payload.replyToStoryId = storyId;
      const response = await this.gateway.send(command) as TdObject;
      return response instanceof TdObject;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Replying to a story failed: %{public}s', String(error));
      return false;
    }
  }
}

export function createReplyToStoryUseCase(gateway: TdGatewayPort): ReplyToStoryUseCase {
  return new ReplyToStoryUseCase(gateway);
}
