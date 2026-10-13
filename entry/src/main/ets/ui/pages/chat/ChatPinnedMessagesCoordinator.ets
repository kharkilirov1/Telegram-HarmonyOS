// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgPinnedMessageListItem } from '../../tg_ui/atoms/TgPinnedMessageList';
import { createLoadPinnedMessagesUseCase, PinnedMessagesPage, PinnedMessageInfo } from '../../../domain/usecases/loadPinnedMessage';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { localized } from '../../../core/utils/AppResource';
import { curves } from '@kit.ArkUI';

export interface ChatPinnedMessagesCoordinatorPort {
  activeChatId: number;
  pageLifecycleToken: number;
  routeContext?: ChatScreenRouteParams;
  routeActivated: boolean;
  pinnedMessageDismissedId: string;
  pinnedMessageHasThumbnail: boolean;
  pinnedMessageId: string;
  pinnedMessageIndex: number;
  pinnedMessagePreview: string;
  pinnedMessageRequestId: number;
  pinnedMessageThumbnailPath: string;
  pinnedMessageTotalCount: number;
  pinnedMessageVisible: boolean;
  pinnedMessages: PinnedMessageInfo[];
  pinnedMessagesListLoading: boolean;
  pinnedMessagesListRequestId: number;
  pinnedMessagesListVisible: boolean;
  pinnedMessagesNextFromMessageId: string;
  applyPinnedMessageInfo(info: PinnedMessageInfo, index: number, totalCount: number): void;
  handlePinnedMessagePress(): void;
  jumpToMessageId(messageId: string): void;
  loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void;
  pinnedMessageTitle(index: number, totalCount: number): string;
  resetPinnedMessageState(): void;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  setPinnedMessagesListVisible(visible: boolean): void;
  getUIContext(): UIContext;
}

function isPinnedOwnerCurrent(host: ChatPinnedMessagesCoordinatorPort, route: ChatScreenRouteParams,
  chatId: number, lifecycleToken: number): boolean {
  return host.routeActivated && host.routeContext === route && route.chatId === chatId &&
    lifecycleToken === host.pageLifecycleToken && chatId === host.activeChatId &&
    host.isRouteContextCurrent(route);
}

export function resetPinnedMessageState(host: ChatPinnedMessagesCoordinatorPort): void {
    host.pinnedMessagesListRequestId++;
    host.pinnedMessageVisible = false;
    host.pinnedMessageId = '0';
    host.pinnedMessagePreview = '';
    host.pinnedMessageHasThumbnail = false;
    host.pinnedMessageThumbnailPath = '';
    host.pinnedMessageIndex = 0;
    host.pinnedMessageTotalCount = 1;
    host.pinnedMessages = [];
    host.pinnedMessagesNextFromMessageId = '0';
    host.pinnedMessagesListVisible = false;
    host.pinnedMessagesListLoading = false;
  }

export function applyPinnedMessageInfo(host: ChatPinnedMessagesCoordinatorPort, info: PinnedMessageInfo, index: number, totalCount: number): void {
    host.pinnedMessageId = info.messageId;
    host.pinnedMessagePreview = info.preview;
    host.pinnedMessageHasThumbnail = info.hasThumbnail;
    host.pinnedMessageThumbnailPath = info.thumbnailPath;
    host.pinnedMessageTotalCount = Math.max(1, totalCount);
    host.pinnedMessageIndex = Math.max(0, Math.min(index, host.pinnedMessageTotalCount - 1));
    host.pinnedMessageVisible = info.messageId !== host.pinnedMessageDismissedId;
  }

export function loadSinglePinnedMessageFallback(host: ChatPinnedMessagesCoordinatorPort, chatId: number, lifecycleToken: number, requestId: number): void {
    const route = host.routeContext;
    if (route === undefined || !isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) ||
      requestId !== host.pinnedMessageRequestId) return;
    const useCase = createLoadPinnedMessagesUseCase(route.gateway);
    useCase.executeSingle(chatId)
      .then((info: PinnedMessageInfo): void => {
        if (!isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) ||
          requestId !== host.pinnedMessageRequestId) {
          return;
        }
        if (!info.isAvailable) {
          host.resetPinnedMessageState();
          return;
        }
        host.pinnedMessages = [info];
        host.applyPinnedMessageInfo(info, 0, 1);
      })
      .catch((_error: Error): void => {
        if (isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) &&
          requestId === host.pinnedMessageRequestId) {
          host.resetPinnedMessageState();
        }
      });
  }

export function loadPinnedMessage(host: ChatPinnedMessagesCoordinatorPort): void {
    const chatId: number = host.activeChatId;
    const lifecycleToken: number = host.pageLifecycleToken;
    const route = host.routeContext;
    if (route === undefined || !isPinnedOwnerCurrent(host, route, chatId, lifecycleToken)) return;
    const requestId: number = ++host.pinnedMessageRequestId;
    // A refreshed base owns a new pagination generation. No old cursor can
    // start another page while that base is unresolved.
    host.pinnedMessagesListRequestId++;
    host.pinnedMessagesListLoading = false;
    host.pinnedMessagesNextFromMessageId = '0';
    host.pinnedMessageVisible = false;
    if (chatId === 0) {
      host.resetPinnedMessageState();
      return;
    }

    const useCase = createLoadPinnedMessagesUseCase(route.gateway);
    useCase.execute(chatId)
      .then((page: PinnedMessagesPage): void => {
        if (!isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) ||
          requestId !== host.pinnedMessageRequestId) {
          return;
        }
        if (page.items.length === 0) {
          host.loadSinglePinnedMessageFallback(chatId, lifecycleToken, requestId);
          return;
        }
        host.pinnedMessages = page.items;
        host.pinnedMessagesNextFromMessageId = page.nextFromMessageId;
        const totalCount: number = Math.max(page.totalCount, page.items.length);
        host.applyPinnedMessageInfo(page.items[0], totalCount - 1, totalCount);
      })
      .catch((_error: Error): void => {
        if (isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) &&
          requestId === host.pinnedMessageRequestId) {
          host.loadSinglePinnedMessageFallback(chatId, lifecycleToken, requestId);
        }
      });
  }

export function handlePinnedMessagePress(host: ChatPinnedMessagesCoordinatorPort): void {
    if (host.pinnedMessageId !== '0') {
      host.jumpToMessageId(host.pinnedMessageId);
    }
  }

export function handlePinnedMessageClose(host: ChatPinnedMessagesCoordinatorPort): void {
    host.pinnedMessageDismissedId = host.pinnedMessageId;
    host.pinnedMessageVisible = false;
  }

export function pinnedMessageTitle(host: ChatPinnedMessagesCoordinatorPort, index: number, totalCount: number): string {
    const defaultTitle: string = localized($r('app.string.pinned_message').id, 'Pinned Message');
    if (totalCount === 2 && index === 0) {
      return localized($r('app.string.previous_pinned_message').id, 'Previous Pinned Message');
    }
    if (totalCount > 2 && index < totalCount - 1) {
      return `${defaultTitle} #${index + 1}`;
    }
    return defaultTitle;
  }

export function pinnedMessageListItems(host: ChatPinnedMessagesCoordinatorPort): TgPinnedMessageListItem[] {
    const items: TgPinnedMessageListItem[] = [];
    for (let i = 0; i < host.pinnedMessages.length; i++) {
      const source: PinnedMessageInfo = host.pinnedMessages[i];
      const item = new TgPinnedMessageListItem();
      const stripeIndex: number = Math.max(0, host.pinnedMessageTotalCount - 1 - i);
      item.messageId = source.messageId;
      item.title = host.pinnedMessageTitle(stripeIndex, host.pinnedMessageTotalCount);
      item.preview = source.preview;
      item.stripeIndex = stripeIndex;
      item.totalCount = host.pinnedMessageTotalCount;
      item.hasThumbnail = source.hasThumbnail;
      item.thumbnailSrc = source.thumbnailPath;
      items.push(item);
    }
    return items;
  }

export function setPinnedMessagesListVisible(host: ChatPinnedMessagesCoordinatorPort, visible: boolean): void {
    host.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(
        TgUiTokens.PINNED_LIST_MOTION_RESPONSE,
        TgUiTokens.PINNED_LIST_MOTION_DAMPING,
        TgUiTokens.PINNED_LIST_MOTION_OVERLAP
      )
    }, () => {
      host.pinnedMessagesListVisible = visible;
    });
  }

export function handlePinnedMessageListPress(host: ChatPinnedMessagesCoordinatorPort): void {
    if (host.pinnedMessageTotalCount <= 1) {
      host.handlePinnedMessagePress();
      return;
    }
    host.setPinnedMessagesListVisible(true);
  }

export function handlePinnedListItemPress(host: ChatPinnedMessagesCoordinatorPort, index: number): void {
    if (index < 0 || index >= host.pinnedMessages.length) {
      return;
    }
    const info: PinnedMessageInfo = host.pinnedMessages[index];
    const stripeIndex: number = Math.max(0, host.pinnedMessageTotalCount - 1 - index);
    host.applyPinnedMessageInfo(info, stripeIndex, host.pinnedMessageTotalCount);
    host.setPinnedMessagesListVisible(false);
    host.scheduleLifecycleTask(0, (): void => {
      host.jumpToMessageId(info.messageId);
    });
  }

export function loadMorePinnedMessages(host: ChatPinnedMessagesCoordinatorPort): void {
    if (host.pinnedMessagesListLoading || host.pinnedMessagesNextFromMessageId === '0' ||
      host.activeChatId === 0) {
      return;
    }

    const chatId: number = host.activeChatId;
    const cursor: string = host.pinnedMessagesNextFromMessageId;
    const lifecycleToken: number = host.pageLifecycleToken;
    const route = host.routeContext;
    if (route === undefined || !isPinnedOwnerCurrent(host, route, chatId, lifecycleToken)) return;
    const baseRequestId: number = host.pinnedMessageRequestId;
    const requestId: number = ++host.pinnedMessagesListRequestId;
    host.pinnedMessagesListLoading = true;
    const useCase = createLoadPinnedMessagesUseCase(route.gateway);
    useCase.execute(chatId, cursor)
      .then((page: PinnedMessagesPage): void => {
        if (!isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) ||
          baseRequestId !== host.pinnedMessageRequestId || requestId !== host.pinnedMessagesListRequestId) {
          return;
        }
        const seenIds: Set<string> = new Set<string>();
        for (let i = 0; i < host.pinnedMessages.length; i++) {
          seenIds.add(host.pinnedMessages[i].messageId);
        }
        const merged: PinnedMessageInfo[] = host.pinnedMessages.slice();
        for (let i = 0; i < page.items.length; i++) {
          if (!seenIds.has(page.items[i].messageId)) {
            seenIds.add(page.items[i].messageId);
            merged.push(page.items[i]);
          }
        }
        host.pinnedMessages = merged;
        host.pinnedMessageTotalCount = Math.max(host.pinnedMessageTotalCount, page.totalCount, merged.length);
        host.pinnedMessagesNextFromMessageId = page.nextFromMessageId === cursor
          ? '0' : page.nextFromMessageId;
        host.pinnedMessagesListLoading = false;
      })
      .catch((_error: Error): void => {
        if (isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) &&
          baseRequestId === host.pinnedMessageRequestId && requestId === host.pinnedMessagesListRequestId) {
          host.pinnedMessagesListLoading = false;
        }
      });
  }
