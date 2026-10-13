// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppState, Message } from '../../../core/model/AppState';
import { resolveSenderName, resolveReplyPreview } from './ChatTimelineVO';
import { LoadRepliedMessageUseCase } from '../../../domain/usecases/loadRepliedMessage';
import { ReplyHydrationCoordinator, ReplyHydrationRequest } from './ReplyHydrationCoordinator';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const MAX_PARALLEL_REPLY_HYDRATION_REQUESTS: number = 4;

export interface ChatReplyHydrationCoordinatorPort {
  activeChatId: number;
  loadRepliedMessageUseCase?: LoadRepliedMessageUseCase;
  pageLifecycleToken: number;
  replyHydrationCoordinator: ReplyHydrationCoordinator;
  replyToAuthor: string;
  replyToMessageId: string;
  replyToPreview: string;
  runMissingReplyHydration(useCase: LoadRepliedMessageUseCase, requests: ReplyHydrationRequest[], lifecycleToken: number, chatId: number): Promise<void>;
}

export function scheduleMissingReplyHydration(host: ChatReplyHydrationCoordinatorPort, state: AppState): void {
    const useCase = host.loadRepliedMessageUseCase;
    const chatMessages = state.messages.messages.get(host.activeChatId);
    if (!useCase || !chatMessages || chatMessages.size === 0) {
      return;
    }

    const associatedMessages = state.messages.associatedMessages.get(host.activeChatId);
    const replyLookup = associatedMessages
      ? new Map<string, Message>(associatedMessages)
      : new Map<string, Message>();
    chatMessages.forEach((message: Message, messageId: string): void => {
      replyLookup.set(messageId, message);
    });
    const requests = host.replyHydrationCoordinator.collect(
      host.activeChatId,
      chatMessages,
      replyLookup
    );
    if (requests.length === 0) {
      return;
    }

    const lifecycleToken = host.pageLifecycleToken;
    const chatId = host.activeChatId;
    host.runMissingReplyHydration(useCase, requests, lifecycleToken, chatId)
      .catch((error: Error): void => {
        if (lifecycleToken === host.pageLifecycleToken && chatId === host.activeChatId) {
          hilog.debug(DOMAIN, TAG, 'Reply hydration batch failed: %{public}s', error.message);
        }
      });
  }

export async function runMissingReplyHydration(host: ChatReplyHydrationCoordinatorPort,
    useCase: LoadRepliedMessageUseCase,
    requests: ReplyHydrationRequest[],
    lifecycleToken: number,
    chatId: number
  ): Promise<void> {
    for (let index = 0; index < requests.length; index += MAX_PARALLEL_REPLY_HYDRATION_REQUESTS) {
      const chunk = requests.slice(index, index + MAX_PARALLEL_REPLY_HYDRATION_REQUESTS);
      await Promise.all(chunk.map((request: ReplyHydrationRequest): Promise<boolean> =>
        useCase.execute(
          request.chatId,
          request.replyingMessageId,
          request.targetMessageId,
          request.targetChatId
        )));

      if (lifecycleToken !== host.pageLifecycleToken || chatId !== host.activeChatId) {
        return;
      }
      for (const request of chunk) {
        host.replyHydrationCoordinator.complete(request);
      }
    }
  }

export function refreshRestoredReplySnippet(host: ChatReplyHydrationCoordinatorPort, state: AppState): void {
    // The degraded chip is produced with the localized generic label, so the
    // detection must compare against the same localized value in every locale.
    const generic = localized($r('app.string.message_action').id, 'Message');
    if (host.replyToMessageId === '0'
      || host.replyToAuthor !== generic || host.replyToPreview !== generic) {
      return;
    }
    const chatMessages = state.messages.messages.get(host.activeChatId);
    const target = chatMessages ? chatMessages.get(host.replyToMessageId) : undefined;
    if (!chatMessages || !target) {
      return;
    }
    host.replyToAuthor = resolveSenderName(target, state);
    host.replyToPreview = resolveReplyPreview(chatMessages, host.replyToMessageId);
  }
