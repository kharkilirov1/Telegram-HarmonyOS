// OpenChat use case - opens a chat and loads its messages
// Business logic for chat navigation and message loading

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createOpenChatCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'OpenChat';
const DOMAIN = 0x0008;

export interface OpenChatParams {
  chatId: ChatId;
  loadMessages?: boolean;
  limit?: number;
}

export class OpenChatUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private currentlyOpenedChatId: ChatId | null = null;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  // Main entry point
  async execute(params: OpenChatParams): Promise<void> {
    const chatId = params.chatId;
    const loadMessages = params.loadMessages !== undefined ? params.loadMessages : true;
    const limit = params.limit !== undefined ? params.limit : 50;

    try {
      hilog.info(DOMAIN, TAG, 'Opening chat %{public}d', chatId);

      // Update currently opened chat
      this.currentlyOpenedChatId = chatId;

      // 1. Send openChat command to TDLib
      const command = createOpenChatCommand(chatId);
      await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Chat opened successfully');

      // 2. Load messages if requested
      if (loadMessages) {
        await this.loadChatMessages(chatId, limit);
      }

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to open chat: %{public}s', err.message);

      // Reset opened chat on error
      this.currentlyOpenedChatId = null;

      throw new AppError(
        AppErrorKind.UNKNOWN,
        `Failed to open chat ${chatId}`,
        err.message,
        0,
        true
      );
    }
  }

  // Load messages for a chat
  private async loadChatMessages(chatId: ChatId, limit: number): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Loading messages for chat %{public}d', chatId);

    try {
      // TODO: In TDLib, use getChatHistory command
      // const command = createGetChatHistoryCommand(chatId, limit);
      // await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Messages loading triggered for chat %{public}d', chatId);

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
