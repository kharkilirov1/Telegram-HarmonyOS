// Photo albums use one TDLib mutation after every picker URI is prepared locally.
// Returned Messages confirms acceptance for sending; updates own delivery state.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSendMediaAlbumCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind, asWriteRequestError } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';

const DOMAIN = 0x0007;
const TAG = 'SendMediaAlbum';
const MAX_CAPTION_LENGTH = 4096;

export class SendMediaAlbumParams {
  chatId: ChatId = 0;
  localPaths: string[] = [];
  caption: string = '';
  replyToMessageId: MessageId = '0';
}

export class SendMediaAlbumError extends AppError {
  outcomeUnknown: boolean;

  constructor(outcomeUnknown: boolean, technicalMessage: string) {
    super(outcomeUnknown ? AppErrorKind.UNKNOWN : AppErrorKind.TDLIB_ERROR,
      outcomeUnknown ? 'Album sending outcome is unknown' : 'Unable to send this photo album',
      technicalMessage, outcomeUnknown ? 0 : 400, false);
    this.name = 'SendMediaAlbumError';
    this.outcomeUnknown = outcomeUnknown;
  }
}

function prepareAlbum(input: SendMediaAlbumParams): SendMediaAlbumParams {
  if (input === undefined || input === null || !Number.isSafeInteger(input.chatId) || input.chatId === 0) {
    throw new SendMediaAlbumError(false, 'Expected a nonzero int53 chat identifier');
  }
  if (!Array.isArray(input.localPaths) || input.localPaths.length < 2 || input.localPaths.length > 10) {
    throw new SendMediaAlbumError(false, 'A photo album requires 2-10 local paths');
  }
  for (const path of input.localPaths) {
    if (typeof path !== 'string' || path.trim().length === 0) {
      throw new SendMediaAlbumError(false, 'Every album item requires a local path');
    }
  }
  if (typeof input.caption !== 'string' || input.caption.length > MAX_CAPTION_LENGTH) {
    throw new SendMediaAlbumError(false, 'Invalid album caption');
  }
  if (typeof input.replyToMessageId !== 'string' ||
    (input.replyToMessageId !== '0' && (!/^[1-9][0-9]*$/.test(input.replyToMessageId) ||
      !Number.isSafeInteger(Number(input.replyToMessageId))))) {
    throw new SendMediaAlbumError(false, 'Expected a positive int53 reply identifier or zero');
  }
  const prepared = new SendMediaAlbumParams();
  prepared.chatId = input.chatId;
  prepared.localPaths = input.localPaths.slice();
  prepared.caption = input.caption;
  prepared.replyToMessageId = input.replyToMessageId;
  return prepared;
}

// message.id is int53 in td_api.tl. Local TDLib pending IDs are also positive:
// MessageId.h:71 and MessagesManager.cpp:20206,27268 use YetUnsent IDs.
// Strict top-level access avoids nested fallback and fractional truncation.
function acceptedMessageId(message: TdObject): string | undefined {
  const numberId = message.getTopLevelNumberStrict('id');
  if (numberId !== undefined) {
    return Number.isSafeInteger(numberId) && numberId > 0 ? numberId.toString() : undefined;
  }
  const stringId = message.getTopLevelStringStrict('id');
  return stringId !== undefined && /^[1-9][0-9]*$/.test(stringId) &&
    Number.isSafeInteger(Number(stringId)) ? stringId : undefined;
}

function verifyAcceptedAlbum(response: Object, chatId: ChatId, count: number): void {
  const messages = response instanceof TdObject && response.getTopLevelStringStrict('@type') === 'messages'
    ? response.getTopLevelObjectArrayStrict('messages') : undefined;
  if (messages === undefined || messages.length !== count) {
    throw new SendMediaAlbumError(true, 'Invalid album response; check the chat before sending again');
  }
  const ids: string[] = [];
  for (const message of messages) {
    if (message === null || message.getTopLevelStringStrict('@type') !== 'message' ||
      message.getTopLevelNumberStrict('chat_id') !== chatId) {
      throw new SendMediaAlbumError(true, 'Album response contains an invalid message or target');
    }
    const id = acceptedMessageId(message);
    if (id === undefined || ids.indexOf(id) >= 0) {
      throw new SendMediaAlbumError(true, 'Album response contains an invalid or duplicate message identifier');
    }
    ids.push(id);
  }
}

export class SendMediaAlbumUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(input: SendMediaAlbumParams): Promise<void> {
    const params = prepareAlbum(input);
    const command = createSendMediaAlbumCommand(params.chatId, params.localPaths,
      params.caption, params.replyToMessageId);
    let response: Object;
    try {
      response = await this.gateway.send(command);
    } catch (error) {
      throw asWriteRequestError(error, 'Could not send this photo album');
    }
    verifyAcceptedAlbum(response, params.chatId, params.localPaths.length);
    hilog.info(DOMAIN, TAG, 'Photo album accepted for sending: %{public}d items', params.localPaths.length);
  }
}

export function createSendMediaAlbumUseCase(gateway: TdGatewayPort): SendMediaAlbumUseCase {
  return new SendMediaAlbumUseCase(gateway);
}
