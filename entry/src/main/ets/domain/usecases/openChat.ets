// OpenChat use case - opens a chat and loads its messages
// Business logic for chat navigation and message loading

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createOpenChatCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { LoadChatHistoryUseCase, LoadChatHistoryParams, createLoadChatHistoryUseCase } from './loadChatHistory';

const TAG = 'OpenChat';
const DOMAIN = 0x0008;

export interface OpenChatParams {
  chatId: ChatId;
  loadMessages?: boolean;
  limit?: number;
}

export class OpenChatUseCase {
  private gateway: TdGatewayPort;
  private currentlyOpenedChatId: ChatId | null = null;
  private openInFlightChatIds: Set<ChatId> = new Set<ChatId>();
  private openRequestSeq: number = 0;
  private historyLoader: LoadChatHistoryUseCase;

  constructor(store: AppStore, gateway: TdGatewayPort, historyLoader?: LoadChatHistoryUseCase) {
    this.gateway = gateway;
    this.historyLoader = historyLoader || createLoadChatHistoryUseCase(store, gateway);
  }

  // Main entry point
  async execute(params: OpenChatParams): Promise<void> {
    const chatId = params.chatId;
    const loadMessages = params.loadMessages !== undefined ? params.loadMessages : true;
    const limit = params.limit !== undefined ? params.limit : 50;
    if (this.openInFlightChatIds.has(chatId)) {
      hilog.info(DOMAIN, TAG, 'Open chat already in progress for %{public}d', chatId);
      return;
    }
    const requestSeq = ++this.openRequestSeq;
    this.openInFlightChatIds.add(chatId);

    try {
      hilog.info(DOMAIN, TAG, 'Opening chat %{public}d', chatId);

      // Update currently opened chat
      this.currentlyOpenedChatId = chatId;

      // 1. Send openChat command to TDLib
      const command = createOpenChatCommand(chatId);
      await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Chat opened successfully');
      if (!this.isLatestRequest(requestSeq)) {
        hilog.info(DOMAIN, TAG, 'Stale openChat response ignored for %{public}d', chatId);
        return;
      }

      // 2. Load messages if requested
      if (loadMessages) {
        await this.loadChatMessagesIfNeeded(chatId, limit);
      }

    } catch (error) {
      const err = error as Error;
      if (!this.isLatestRequest(requestSeq)) {
        hilog.info(DOMAIN, TAG, 'Ignoring stale openChat failure for %{public}d: %{public}s', chatId, err.message);
        return;
      }
      hilog.error(DOMAIN, TAG, 'Failed to open chat: %{public}s', err.message);

      // Reset opened chat on error
      if (this.currentlyOpenedChatId === chatId) {
        this.currentlyOpenedChatId = null;
      }

      throw new AppError(
        AppErrorKind.UNKNOWN,
        `Failed to open chat ${chatId}`,
        err.message,
        0,
        true
      );
    } finally {
      this.openInFlightChatIds.delete(chatId);
    }
  }

  private isLatestRequest(requestSeq: number): boolean {
    return requestSeq === this.openRequestSeq;
  }

  // Load messages for a chat when local cache is empty.
  private async loadChatMessagesIfNeeded(chatId: ChatId, limit: number): Promise<void> {
    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.limit = limit;
    try {
      await this.historyLoader.execute(params);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to load messages: %{public}s', err.message);
      // Don't throw - chat is still opened
    }
  }

  // Get currently opened chat
  getOpenedChatId(): ChatId | null {
    return this.currentlyOpenedChatId;
  }

  // Close current chat
  closeCurrentChat(): void {
    hilog.info(DOMAIN, TAG, 'Closing chat %{public}d', this.currentlyOpenedChatId || 0);
    this.currentlyOpenedChatId = null;
  }

  // Check if a chat is currently opened
  isChatOpened(chatId: ChatId): boolean {
    return this.currentlyOpenedChatId === chatId;
  }
}

// Factory function
export function createOpenChatUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): OpenChatUseCase {
  return new OpenChatUseCase(store, gateway);
}
