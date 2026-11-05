// I6: set or remove a reaction on a story. TDLib answers Ok and sends updateStory with the new
// chosen_reaction_type, so the store updates through the normalizer instead of an optimistic write here.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSetStoryReactionCommand } from '../../core/model/AppCommand';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00B6;
const TAG = 'SetStoryReaction';

export class SetStoryReactionUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Passing the key that is already chosen removes it, which is how Telegram toggles reactions.
  async execute(posterChatId: number, storyId: number, reactionKey: string,
    currentKey: string): Promise<boolean> {
    if (posterChatId === 0 || storyId <= 0) {
      return false;
    }
    const nextKey = reactionKey === currentKey ? '' : reactionKey;
    try {
      await this.gateway.send(createSetStoryReactionCommand(posterChatId, storyId, nextKey));
      return true;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Setting a story reaction failed: %{public}s', String(error));
      return false;
    }
  }
}

export function createSetStoryReactionUseCase(gateway: TdGatewayPort): SetStoryReactionUseCase {
  return new SetStoryReactionUseCase(gateway);
}
