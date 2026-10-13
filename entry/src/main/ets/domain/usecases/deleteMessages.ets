// DeleteMessages use case — deletes messages via TDLib
// TDLib responds with updateDeleteMessages → MessageNormalizer → messagesReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createDeleteMessagesCommand, createGetMessagePropertiesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';

const TAG = 'DeleteMessages';
const DOMAIN = 0x0011;

export class DeleteMessagesParams {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
  revoke: boolean = false; // Never escalate an omitted option to deletion for everyone.
}

export class DeleteMessagesAvailability {
  forSelf: boolean = true;
  forEveryone: boolean = true;
}

export class DeleteMessagesEligibilityError extends AppError {
  constructor() {
    super(AppErrorKind.TDLIB_ERROR, 'Deletion unavailable', 'Message deletion mode or context is unavailable', 0, false);
  }
}

export class DeleteMessagesOutcomeError extends AppError {
  constructor() {
    super(AppErrorKind.UNKNOWN, 'Deletion was not confirmed', 'Check the chat before retrying', 0, false);
  }
}

export class DeleteMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  prepare(params: DeleteMessagesParams): DeleteMessagesParams {
    if (!Number.isSafeInteger(params.chatId) || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!Array.isArray(params.messageIds) || params.messageIds.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'No messages to delete', 'Input validation failed', 400, false);
    }
    if (typeof params.revoke !== 'boolean') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid revoke option', 'Expected a boolean', 400, false);
    }
    const ids: MessageId[] = [];
    for (const id of params.messageIds) {
      if (typeof id !== 'string' || !/^[1-9][0-9]*$/.test(id) || !Number.isSafeInteger(Number(id))) {
        throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message identifier', 'Expected positive int53', 400, false);
      }
      if (ids.indexOf(id) < 0) ids.push(id);
    }
    // deleteMessages has no forwardMessages-style max-100/sorted-ID contract.
    const prepared = new DeleteMessagesParams();
    prepared.chatId = params.chatId;
    prepared.messageIds = ids;
    prepared.revoke = params.revoke;
    return prepared;
  }

  async getAvailability(chatId: ChatId, messageIds: MessageId[],
    canContinue: () => boolean = (): boolean => true): Promise<DeleteMessagesAvailability> {
    const input = new DeleteMessagesParams();
    input.chatId = chatId;
    input.messageIds = messageIds;
    const params = this.prepare(input);
    const result = new DeleteMessagesAvailability();
    for (const id of params.messageIds) {
      if (!canContinue()) throw new DeleteMessagesEligibilityError();
      const properties = await this.gateway.send(createGetMessagePropertiesCommand(params.chatId, id));
      if (!canContinue()) throw new DeleteMessagesEligibilityError();
      if (!(properties instanceof TdObject) || properties.getTopLevelStringStrict('@type') !== 'messageProperties') {
        throw new DeleteMessagesEligibilityError();
      }
      const forSelf = properties.getTopLevelBooleanStrict('can_be_deleted_only_for_self');
      const forEveryone = properties.getTopLevelBooleanStrict('can_be_deleted_for_all_users');
      if (forSelf === undefined || forEveryone === undefined) throw new DeleteMessagesEligibilityError();
      result.forSelf = result.forSelf && forSelf;
      result.forEveryone = result.forEveryone && forEveryone;
    }
    return result;
  }

  async execute(input: DeleteMessagesParams, canDispatch: () => boolean = (): boolean => true): Promise<void> {
    const params = this.prepare(input);
    const availability = await this.getAvailability(params.chatId, params.messageIds, canDispatch);
    if (!canDispatch() || !(params.revoke ? availability.forEveryone : availability.forSelf)) {
      throw new DeleteMessagesEligibilityError();
    }
    try {
      hilog.info(DOMAIN, TAG, 'Deleting %{public}d messages in chat %{public}d (revoke=%{public}s)',
        params.messageIds.length, params.chatId, String(params.revoke));

      const command = createDeleteMessagesCommand(params.chatId, params.messageIds, params.revoke);
      const response = await this.gateway.send(command);
      if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'ok') {
        throw new DeleteMessagesOutcomeError();
      }

      hilog.info(DOMAIN, TAG, 'Deletion request confirmed by TDLib');
      // TDLib will send updateDeleteMessages via event pipeline
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to delete messages: %{public}s', err.message);
      throw new DeleteMessagesOutcomeError();
    }
  }
}

export function createDeleteMessagesUseCase(gateway: TdGatewayPort): DeleteMessagesUseCase {
  return new DeleteMessagesUseCase(gateway);
}
