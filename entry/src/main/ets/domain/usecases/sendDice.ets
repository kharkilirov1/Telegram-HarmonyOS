// D27: sending a dice/darts/slots message. TDLib picks the value, so the use case only validates that the
// emoji is one Telegram animates and forwards it.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSendDiceCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00D27;
const TAG = 'SendDice';

// The set Telegram animates in the attachment/sticker pickers; anything else is rejected locally.
export const DICE_EMOJIS: string[] = ['🎲', '🎯', '🏀', '⚽', '🎳', '🎰'];

export function isSupportedDiceEmoji(emoji: string): boolean {
  return DICE_EMOJIS.includes(emoji);
}

export class SendDiceUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: number, emoji: string = '🎲'): Promise<boolean> {
    if (chatId === 0 || !isSupportedDiceEmoji(emoji)) {
      return false;
    }
    try {
      const response = await this.gateway.send(createSendDiceCommand(chatId, emoji));
      return response instanceof TdObject;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Sending a dice failed: %{public}s', String(error));
      return false;
    }
  }
}

export function createSendDiceUseCase(gateway: TdGatewayPort): SendDiceUseCase {
  return new SendDiceUseCase(gateway);
}
