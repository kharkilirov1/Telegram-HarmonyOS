// EditMessage use case — edits text of an existing message via TDLib
// TDLib responds with updateMessageContent → MessageNormalizer → messagesReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createEditMessageTextCommand, createEditMessageCaptionCommand, createGetMessageCommand, createGetMessagePropertiesCommand, EditMessageEntity, EditMessageLinkPreviewOptions } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';
import { readEditEntities, reconcileEditEntities, readEditPreviewOptions } from './EditMessageFormatting';

const TAG = 'EditMessage';
const DOMAIN = 0x0010;

const MAX_MESSAGE_LENGTH = 4096;

export class EditMessageParams {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  text: string = '';
  expectedOriginalText?: string;
}

export class EditMessageSnapshot {
  messageId: MessageId = '0';
  kind: string = 'text';
  text: string = '';
  showCaptionAboveMedia: boolean = false;
  entities: EditMessageEntity[] = [];
  linkPreviewOptions?: EditMessageLinkPreviewOptions;
}

// Native MessageId.h: low 3 bits mark scheduled-server; bits 3..20 hold
// server_id, while high bits hold date. Never use JS >> on an int53 ID.
function scheduledServerId(id: number): number {
  if (!Number.isSafeInteger(id) || id <= 0 || id > 2251799813685248 || id % 8 !== 4) return 0;
  return Math.floor(id / 8) % 262144;
}

export function matchesEditMessageId(requested: number, actual: number, scheduled: boolean): boolean {
  if (scheduledServerId(requested) !== 0 || scheduledServerId(actual) !== 0) {
    return scheduled && scheduledServerId(requested) > 0 && scheduledServerId(requested) === scheduledServerId(actual);
  }
  return requested === actual;
}

export class EditMessageEligibilityError extends AppError {
  constructor() {
    super(AppErrorKind.TDLIB_ERROR, 'Message editing unavailable', 'Invalid source, content or current editing permission', 0, false);
  }
}

export class EditMessageOutcomeError extends AppError {
  constructor() {
    super(AppErrorKind.UNKNOWN, 'Message edit was not confirmed', 'Check the message before retrying; keep the draft', 0, false);
  }
}

export class EditMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  prepare(params: EditMessageParams): EditMessageParams {
    if (!Number.isSafeInteger(params.chatId) || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (typeof params.messageId !== 'string' || !/^[1-9][0-9]*$/.test(params.messageId) ||
      !Number.isSafeInteger(Number(params.messageId))) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid messageId', 'Input validation failed', 400, false);
    }
    if (typeof params.text !== 'string') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message text', 'Expected a string', 400, false);
    }
    if (params.expectedOriginalText !== undefined && typeof params.expectedOriginalText !== 'string') {
      throw new EditMessageEligibilityError();
    }
    if (params.text.length > MAX_MESSAGE_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, `Message too long: ${params.text.length} > ${MAX_MESSAGE_LENGTH}`, 'Input validation failed', 400, false);
    }

    const prepared = new EditMessageParams();
    prepared.chatId = params.chatId;
    prepared.messageId = params.messageId;
    prepared.text = params.text;
    prepared.expectedOriginalText = params.expectedOriginalText;
    return prepared;
  }

  private readSnapshot(response: Object, chatId: ChatId, messageId: MessageId): EditMessageSnapshot {
    if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'message' ||
      response.getTopLevelNumberStrict('chat_id') !== chatId) throw new EditMessageEligibilityError();
    const id = response.getTopLevelNumberStrict('id');
    const stateType = response.getTopLevelObjectStrict('scheduling_state')?.getTopLevelStringStrict('@type') ?? '';
    const scheduled = ['messageSchedulingStateSendAtDate', 'messageSchedulingStateSendWhenOnline',
      'messageSchedulingStateSendWhenVideoProcessed'].includes(stateType);
    if (id === undefined || !Number.isSafeInteger(id) || !matchesEditMessageId(Number(messageId), id, scheduled)) {
      throw new EditMessageEligibilityError();
    }
    const content = response.getTopLevelObjectStrict('content');
    const type = content?.getTopLevelStringStrict('@type');
    if (content === undefined || type === undefined) throw new EditMessageEligibilityError();
    const snapshot = new EditMessageSnapshot();
    snapshot.messageId = String(id);
    let formatted: TdObject | undefined;
    if (type === 'messageText') {
      formatted = content.getTopLevelObjectStrict('text');
      snapshot.linkPreviewOptions = readEditPreviewOptions(content);
    } else if (type === 'messageGame') {
      formatted = content.getTopLevelObjectStrict('game')?.getTopLevelObjectStrict('text');
    } else if (['messageAnimation', 'messageAudio', 'messageDocument', 'messagePhoto', 'messageVideo',
      'messageVoiceNote', 'messagePaidMedia'].includes(type)) {
      snapshot.kind = 'caption';
      formatted = content.getTopLevelObjectStrict('caption');
      if (['messageAnimation', 'messagePhoto', 'messageVideo', 'messagePaidMedia'].includes(type)) {
        const above = content.getTopLevelBooleanStrict('show_caption_above_media');
        if (above === undefined) throw new EditMessageEligibilityError();
        snapshot.showCaptionAboveMedia = above;
      }
    } else {
      throw new EditMessageEligibilityError();
    }
    const text = formatted?.getTopLevelStringStrict('text');
    if (formatted?.getTopLevelStringStrict('@type') !== 'formattedText' || text === undefined) {
      throw new EditMessageEligibilityError();
    }
    snapshot.text = text;
    snapshot.entities = readEditEntities(formatted, text);
    return snapshot;
  }

  async execute(input: EditMessageParams,
    canDispatch: () => boolean = (): boolean => true): Promise<EditMessageSnapshot> {
    const params = this.prepare(input);
    if (!canDispatch()) throw new EditMessageEligibilityError();
    const message = await this.gateway.send(createGetMessageCommand(params.chatId, params.messageId));
    if (!canDispatch()) throw new EditMessageEligibilityError();
    const source = this.readSnapshot(message, params.chatId, params.messageId);
    if (params.expectedOriginalText !== undefined && params.expectedOriginalText !== source.text) {
      throw new EditMessageEligibilityError();
    }
    // A text message must remain nonempty; an empty caption removes it.
    if (source.kind === 'text' && params.text.trim().length === 0) throw new EditMessageEligibilityError();
    const entities = reconcileEditEntities(source.text, params.text, source.entities);
    const properties = await this.gateway.send(createGetMessagePropertiesCommand(params.chatId, source.messageId));
    if (!canDispatch() || !(properties instanceof TdObject) ||
      properties.getTopLevelStringStrict('@type') !== 'messageProperties' ||
      properties.getTopLevelBooleanStrict('can_be_edited') !== true) throw new EditMessageEligibilityError();
    try {
      const command = source.kind === 'caption'
        ? createEditMessageCaptionCommand(params.chatId, source.messageId, params.text, source.showCaptionAboveMedia, entities)
        : createEditMessageTextCommand(params.chatId, source.messageId, params.text, entities, source.linkPreviewOptions);
      const response = await this.gateway.send(command);
      const edited = this.readSnapshot(response, params.chatId, source.messageId);
      if (edited.kind !== source.kind) throw new EditMessageOutcomeError();
      hilog.info(DOMAIN, TAG, 'Message edit confirmed by TDLib');
      return edited;
    } catch (_error) {
      // No automatic replay and no optimistic store rewrite on unknown outcome.
      throw new EditMessageOutcomeError();
    }
  }
}

export function createEditMessageUseCase(gateway: TdGatewayPort): EditMessageUseCase {
  return new EditMessageUseCase(gateway);
}
