// Block / unblock a message sender — Settings → Blocked Users and the profile action (H8).
// TDLib: setMessageSenderBlockList(sender_id, block_list) = Ok (td_api.tl:13175); blocking sends
// blockListMain, unblocking sends a null block list. Only users and supergroups can be blocked.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSetMessageSenderBlockListCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0037;
const TAG = 'SetMessageSenderBlocked';

export class SetMessageSenderBlockedUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async block(senderType: 'user' | 'chat', senderId: number): Promise<void> {
    await this.apply(senderType, senderId, true);
  }

  async unblock(senderType: 'user' | 'chat', senderId: number): Promise<void> {
    await this.apply(senderType, senderId, false);
  }

  private async apply(senderType: 'user' | 'chat', senderId: number, blocked: boolean): Promise<void> {
    if ((senderType !== 'user' && senderType !== 'chat') || !Number.isSafeInteger(senderId) || senderId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid sender', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, '%{public}s %{public}s %{public}d',
        blocked ? 'Blocking' : 'Unblocking', senderType, senderId);
      await this.gateway.send(createSetMessageSenderBlockListCommand(senderType, senderId, blocked));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'setMessageSenderBlockList failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN,
        blocked ? 'Failed to block the sender' : 'Failed to unblock the sender', err.message, 0, true);
    }
  }
}

export function createSetMessageSenderBlockedUseCase(gateway: TdGatewayPort): SetMessageSenderBlockedUseCase {
  return new SetMessageSenderBlockedUseCase(gateway);
}
