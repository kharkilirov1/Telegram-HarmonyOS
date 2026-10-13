// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, timelineEntryContainsMessageId } from './ChatTimelineVO';
import { PendingSharedMediaAction } from './PendingSharedMediaActionSignal';
import { LoadChatHistoryUseCase } from '../../../domain/usecases/loadChatHistory';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatMessageJumpCoordinatorPort {
  activeChatId: number;
  blockAutoPaginationUntilUserScroll: boolean;
  dataSource: ChatTimelineDataSource;
  jumpRequestToken: number;
  listScroller: Scroller;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  pageLifecycleToken: number;
  pendingJumpAttempts: number;
  pendingJumpMessageId: string;
  pendingSharedMediaAction: PendingSharedMediaAction | undefined;
  flashSearchHit(messageId: string, index: number): void;
  fulfillPendingSharedMediaAction(): void;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  scrollToMessageId(messageId: string): boolean;
}

export function scrollToMessageId(host: ChatMessageJumpCoordinatorPort, messageId: string): boolean {
    const count = host.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      const entry: ChatTimelineEntryVO = host.dataSource.getData(i);
      if (timelineEntryContainsMessageId(entry, messageId)) {
        // Center keeps the target clear of the floating top bar/pinned panel
        // and also works for a member collapsed into a photo-album row.
        host.listScroller.scrollToIndex(i, false, ScrollAlign.CENTER);
        host.flashSearchHit(messageId, i);
        return true;
      }
    }
    return false;
  }

export function jumpToMessageId(host: ChatMessageJumpCoordinatorPort, messageId: string): void {
    const supersedesPendingJump = host.pendingJumpMessageId !== '';
    const jumpToken = ++host.jumpRequestToken;
    host.pendingJumpMessageId = '';
    host.pendingJumpAttempts = 0;
    // A pending jump may still own a queued reset/response. Supersede its
    // history window even when the new target is in the old displayed data.
    if (!supersedesPendingJump && host.scrollToMessageId(messageId)) {
      hilog.info(DOMAIN, TAG, 'Jump: scrolled to %{public}s in loaded timeline', messageId);
      return;
    }
    const useCase = host.loadChatHistoryUseCase;
    if (!useCase || host.activeChatId === 0) {
      return;
    }
    const token = host.pageLifecycleToken;
    host.pendingJumpMessageId = messageId;
    host.blockAutoPaginationUntilUserScroll = true;
    useCase.loadAroundMessage(host.activeChatId, messageId)
      .then((ok: boolean) => {
        if (token !== host.pageLifecycleToken || jumpToken !== host.jumpRequestToken) {
          return;
        }
        if (!ok) {
          host.pendingJumpMessageId = '';
        }
      })
      .catch((error: Error) => {
        if (token === host.pageLifecycleToken && jumpToken === host.jumpRequestToken) {
          host.pendingJumpMessageId = '';
          hilog.warn(DOMAIN, TAG, 'Jump failed: %{public}s', error.message);
        }
      });
  }

export function fulfillPendingJump(host: ChatMessageJumpCoordinatorPort): void {
    if (host.pendingJumpMessageId === '') {
      return;
    }
    const targetId = host.pendingJumpMessageId;
    const jumpToken = host.jumpRequestToken;
    host.pendingJumpAttempts++;
    // scrollToIndex right after a full reload needs the List to settle first
    host.scheduleLifecycleTask(16, () => {
      if (jumpToken !== host.jumpRequestToken || host.pendingJumpMessageId !== targetId) {
        return;
      }
      if (host.scrollToMessageId(targetId)) {
        host.pendingJumpMessageId = '';
        host.fulfillPendingSharedMediaAction();
      } else if (host.pendingJumpAttempts >= 4) {
        host.pendingJumpMessageId = '';
        host.pendingSharedMediaAction = undefined;
      }
    });
  }
