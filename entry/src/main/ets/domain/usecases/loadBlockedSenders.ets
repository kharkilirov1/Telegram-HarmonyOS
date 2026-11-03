// Blocked users — Settings → Privacy → Blocked Users (H8).
// TDLib: getBlockedMessageSenders(block_list, offset, limit) = MessageSenders (td_api.tl:13188),
// setMessageSenderBlockList(sender_id, block_list) = Ok (td_api.tl:13175, null unblocks).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdObject } from '../../models/TdTypes';
import {
  BlockListKind,
  createGetBlockedMessageSendersCommand,
  createSetMessageSenderBlockListCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  BlockedSenderDto,
  BlockedSendersPage,
  createBlockedSendersPageFromTd
} from '../../core/model/dto/BlockedSenderDto';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0035;
const TAG = 'LoadBlockedSenders';
export const BLOCKED_SENDERS_PAGE_SIZE: number = 100;

export class LoadBlockedSendersUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // blockList selects which TDLib block list is read: main (messages) or stories.
  async fetchPage(
    offset: number = 0,
    limit: number = BLOCKED_SENDERS_PAGE_SIZE,
    blockList: BlockListKind = 'main'
  ): Promise<BlockedSendersPage> {
    if (!Number.isSafeInteger(offset) || offset < 0 ||
      !Number.isSafeInteger(limit) || limit <= 0 || limit > 100) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid paging', 'Input validation failed', 400, false);
    }
    try {
      const response = await this.gateway.send(
        createGetBlockedMessageSendersCommand(blockList, offset, limit)) as TdObject;
      return createBlockedSendersPageFromTd(response);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getBlockedMessageSenders failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load blocked users', err.message, 0, true);
    }
  }

  async unblock(sender: BlockedSenderDto): Promise<void> {
    if (sender.senderId === 0 || !Number.isSafeInteger(sender.senderId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid sender', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Unblocking %{public}s %{public}d', sender.senderType, sender.senderId);
      await this.gateway.send(
        createSetMessageSenderBlockListCommand(sender.senderType, sender.senderId, false));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Unblock failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to unblock the sender', err.message, 0, true);
    }
  }
}

export function createLoadBlockedSendersUseCase(gateway: TdGatewayPort): LoadBlockedSendersUseCase {
  return new LoadBlockedSendersUseCase(gateway);
}
