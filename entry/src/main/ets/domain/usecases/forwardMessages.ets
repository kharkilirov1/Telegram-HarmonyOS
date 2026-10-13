// ForwardMessages use case — forwards messages to another chat via TDLib
// TDLib responds with updateNewMessage for each forwarded message

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createForwardMessagesCommand, createGetChatCommand, createGetMessagePropertiesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind, asWriteRequestError, isSilentTdlibError } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';

const TAG = 'ForwardMessages';
const DOMAIN = 0x0012;

// td/telegram/MessageId.h: server IDs are int32 server IDs shifted by 20.
// Arithmetic (not JS bitwise operations) preserves the int53 message ID.
const SERVER_MESSAGE_ID_FACTOR = 1048576;
const MAX_SERVER_MESSAGE_ID = 2147483647 * SERVER_MESSAGE_ID_FACTOR;

export class ForwardMessagesParams {
  chatId: ChatId = 0;         // target chat
  fromChatId: ChatId = 0;     // source chat
  messageIds: MessageId[] = [];
  sendCopy: boolean = false;       // true = copy without "Forwarded from" header
  removeCaption: boolean = false;  // true = remove caption from media
}

export class ForwardSourceAvailability {
  ordinaryTargets: boolean = true;
  secretTargets: boolean = true;
}

export class ForwardMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Synchronous preflight is also called before the controller sends a comment.
  // Snapshot input: picker ordering/duplicates must not corrupt raw JSON IDs.
  prepare(params: ForwardMessagesParams): ForwardMessagesParams {
    if (!Number.isSafeInteger(params.chatId) || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid target chatId', 'Input validation failed', 400, false);
    }
    if (!Number.isSafeInteger(params.fromChatId) || params.fromChatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid source chatId', 'Input validation failed', 400, false);
    }
    if (!Array.isArray(params.messageIds) || params.messageIds.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'No messages to forward', 'Input validation failed', 400, false);
    }
    if (typeof params.sendCopy !== 'boolean' || typeof params.removeCaption !== 'boolean') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid copy options', 'Expected booleans', 400, false);
    }

    const ids: MessageId[] = [];
    for (const id of params.messageIds) {
      if (typeof id !== 'string' || !/^[1-9][0-9]*$/.test(id) || !Number.isSafeInteger(Number(id))) {
        throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message identifier', 'Expected positive int53', 400, false);
      }
      if (ids.indexOf(id) < 0) ids.push(id);
    }
    if (ids.length > 100) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Too many messages to forward', 'Maximum is 100', 400, false);
    }
    ids.sort((a: string, b: string): number => Number(a) - Number(b));
    const prepared = new ForwardMessagesParams();
    prepared.chatId = params.chatId;
    prepared.fromChatId = params.fromChatId;
    prepared.messageIds = ids;
    prepared.sendCopy = params.sendCopy;
    // Match the public TDLib contract despite version-specific bulk-handler behavior.
    prepared.removeCaption = params.sendCopy && params.removeCaption;
    return prepared;
  }

  // Target-independent selection check for the UI's default sendCopy=false mode.
  // Intersect routes across the batch: per-message (ordinary OR secret) is unsafe
  // when no single destination can accept the whole selection.
  async getSourceAvailability(sourceChatId: ChatId, messageIds: MessageId[],
    canContinue: () => boolean = (): boolean => true): Promise<ForwardSourceAvailability> {
    const input = new ForwardMessagesParams();
    input.chatId = sourceChatId;
    input.fromChatId = sourceChatId;
    input.messageIds = messageIds;
    const params = this.prepare(input);
    const availability = new ForwardSourceAvailability();
    for (const id of params.messageIds) {
      if (!canContinue()) throw new ForwardMessagesEligibilityError();
      const properties = await this.gateway.send(createGetMessagePropertiesCommand(params.fromChatId, id));
      if (!canContinue()) throw new ForwardMessagesEligibilityError();
      const numericId = Number(id);
      const serverId = numericId <= MAX_SERVER_MESSAGE_ID && numericId % SERVER_MESSAGE_ID_FACTOR === 0;
      if (!(properties instanceof TdObject) || properties.getTopLevelStringStrict('@type') !== 'messageProperties') {
        throw new ForwardMessagesEligibilityError();
      }
      const ordinary = properties.getTopLevelBooleanStrict(serverId ? 'can_be_forwarded' : 'can_be_copied');
      const secret = properties.getTopLevelBooleanStrict('can_be_copied_to_secret_chat');
      if (ordinary === undefined || secret === undefined) throw new ForwardMessagesEligibilityError();
      availability.ordinaryTargets = availability.ordinaryTargets && ordinary;
      availability.secretTargets = availability.secretTargets && secret;
    }
    return availability;
  }

  // MessageProperties is a local-state snapshot with no IDs/revision in its response.
  // Bind each response to this captured request; never cache eligibility as permission.
  async validateEligibility(input: ForwardMessagesParams, canDispatch: () => boolean = (): boolean => true): Promise<void> {
    const params = this.prepare(input);
    if (!canDispatch()) throw new ForwardMessagesEligibilityError();
    const target = await this.gateway.send(createGetChatCommand(params.chatId));
    if (!canDispatch()) throw new ForwardMessagesEligibilityError();
    const targetType = target instanceof TdObject && target.getTopLevelStringStrict('@type') === 'chat' &&
      target.getTopLevelNumberStrict('id') === params.chatId
      ? target.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('@type') : undefined;
    if (targetType !== 'chatTypePrivate' && targetType !== 'chatTypeBasicGroup' &&
      targetType !== 'chatTypeSupergroup' && targetType !== 'chatTypeSecret') {
      throw new ForwardMessagesEligibilityError();
    }
    for (const id of params.messageIds) {
      const properties = await this.gateway.send(createGetMessagePropertiesCommand(params.fromChatId, id));
      if (!canDispatch()) throw new ForwardMessagesEligibilityError();
      const numericId = Number(id);
      const serverId = numericId <= MAX_SERVER_MESSAGE_ID && numericId % SERVER_MESSAGE_ID_FACTOR === 0;
      const flag = targetType === 'chatTypeSecret' ? 'can_be_copied_to_secret_chat'
        : params.sendCopy || !serverId ? 'can_be_copied' : 'can_be_forwarded';
      if (!(properties instanceof TdObject) || properties.getTopLevelStringStrict('@type') !== 'messageProperties' ||
        properties.getTopLevelBooleanStrict(flag) !== true) {
        throw new ForwardMessagesEligibilityError();
      }
    }
  }

  async execute(input: ForwardMessagesParams, canDispatch: () => boolean = (): boolean => true): Promise<void> {
    const params = this.prepare(input);
    await this.validateEligibility(params, canDispatch);
    // A caller's capability may have changed during any of the offline reads.
    if (!canDispatch()) throw new ForwardMessagesEligibilityError();
    let response: Object;
    try {
      hilog.info(DOMAIN, TAG, 'Forwarding %{public}d messages from chat %{public}d to chat %{public}d',
        params.messageIds.length, params.fromChatId, params.chatId);

      const command = createForwardMessagesCommand(
        params.chatId, params.fromChatId, params.messageIds,
        params.sendCopy, params.removeCaption
      );
      response = await this.gateway.send(command);
    } catch (error) {
      const failure = asWriteRequestError(error, 'Could not forward messages');
      if (!isSilentTdlibError(failure)) {
        hilog.error(DOMAIN, TAG, 'Failed to forward messages: %{public}s', failure.message);
      }
      throw failure;
    }
    // TDLib returns a positional Messages vector; null means not forwarded.
    // Never infer success from a fulfilled promise, total_count or update timing.
    const messages = response instanceof TdObject && response.getTopLevelStringStrict('@type') === 'messages'
      ? response.getTopLevelObjectArrayStrict('messages') : undefined;
    if (messages === undefined || messages.length !== params.messageIds.length) {
      throw new ForwardMessagesResultError([], 0, false);
    }
    const retryIds: MessageId[] = [];
    let acceptedCount = 0;
    for (let index = 0; index < messages.length; index++) {
      const message = messages[index];
      if (message === null) {
        retryIds.push(params.messageIds[index]);
      } else {
        const id = message.getTopLevelNumberStrict('id');
        if (message.getTopLevelStringStrict('@type') !== 'message' || typeof id !== 'number' ||
          !Number.isSafeInteger(id) || id <= 0 || message.getTopLevelNumberStrict('chat_id') !== params.chatId) {
          throw new ForwardMessagesResultError([], 0, false);
        }
        acceptedCount++;
      }
    }
    if (retryIds.length > 0) throw new ForwardMessagesResultError(retryIds, acceptedCount, true);
    hilog.info(DOMAIN, TAG, 'Forwarding accepted for %{public}d messages', acceptedCount);
    // Accepted for sending is not server delivery; updates own delivery state.
  }
}

export class ForwardMessagesEligibilityError extends AppError {
  constructor() {
    super(AppErrorKind.TDLIB_ERROR, 'Unable to forward this selection',
      'Message eligibility or forwarding context is unavailable', 0, true);
  }
}

export class ForwardMessagesResultError extends AppError {
  retryMessageIds: MessageId[];
  acceptedCount: number;
  outcomeKnown: boolean;

  constructor(retryMessageIds: MessageId[], acceptedCount: number, outcomeKnown: boolean) {
    super(AppErrorKind.TDLIB_ERROR, 'Forwarding was not fully accepted',
      outcomeKnown ? 'Some messages cannot be forwarded' : 'Invalid forwarding response; check destination before retry',
      0, outcomeKnown && retryMessageIds.length > 0);
    this.retryMessageIds = [...retryMessageIds];
    this.acceptedCount = acceptedCount;
    this.outcomeKnown = outcomeKnown;
  }
}

export function createForwardMessagesUseCase(gateway: TdGatewayPort): ForwardMessagesUseCase {
  return new ForwardMessagesUseCase(gateway);
}
