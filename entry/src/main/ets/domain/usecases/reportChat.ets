// Chat report — Report entry in chat actions (C10 remainder / S12d).
// TDLib: reportChat (td_api.tl:14338). The first request sends empty option_id and returns the option
// list; the chosen option is sent back. Text-required and message-selection steps are surfaced as
// typed results instead of being silently skipped.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import { createReportChatCommand, ReportChatPayload } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { createReportChatStepFromTd, ReportChatStepDto } from '../../core/model/dto/ReportChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x003d;
const TAG = 'ReportChat';

export class ReportChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Starts the flow: an empty option_id asks TDLib for the applicable reasons.
  async start(chatId: ChatId): Promise<ReportChatStepDto> {
    return this.request(chatId, '', '');
  }

  // Continues the flow with the option the user chose.
  async chooseOption(chatId: ChatId, optionId: string): Promise<ReportChatStepDto> {
    if (optionId.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid option', 'Input validation failed', 400, false);
    }
    return this.request(chatId, optionId, '');
  }

  // Finishes a report whose reason requires a free-text comment.
  async submitComment(chatId: ChatId, optionId: string, text: string): Promise<ReportChatStepDto> {
    const comment = text.trim();
    if (optionId.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid option', 'Input validation failed', 400, false);
    }
    if (comment.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Report comment is required',
        'Input validation failed', 400, false);
    }
    return this.request(chatId, optionId, comment);
  }

  // Finishes a report whose reason requires the offending messages.
  async submitMessages(chatId: ChatId, optionId: string, messageIds: number[]): Promise<ReportChatStepDto> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (messageIds.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Report messages are required',
        'Input validation failed', 400, false);
    }
    for (const messageId of messageIds) {
      if (!Number.isSafeInteger(messageId) || messageId <= 0) {
        throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message id', 'Input validation failed', 400,
          false);
      }
    }
    return this.request(chatId, optionId, '', messageIds);
  }

  private async request(chatId: ChatId, optionId: string, text: string,
    messageIds: number[] = []): Promise<ReportChatStepDto> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    const payload = new ReportChatPayload();
    payload.chatId = chatId;
    payload.optionId = optionId;
    payload.text = text;
    payload.messageIds = messageIds;
    try {
      const response = await this.gateway.send(createReportChatCommand(payload)) as TdObject;
      return createReportChatStepFromTd(response);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'reportChat failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to report the chat', err.message, 0, true);
    }
  }
}

export function createReportChatUseCase(gateway: TdGatewayPort): ReportChatUseCase {
  return new ReportChatUseCase(gateway);
}
