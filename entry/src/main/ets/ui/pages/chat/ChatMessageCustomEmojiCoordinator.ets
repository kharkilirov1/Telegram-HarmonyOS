// D16: message custom emoji prefetch. Rows are built synchronously, so this coordinator asks the resolver
// for the files of the rows that are on screen and triggers one rebuild when anything new arrived.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TextEntity } from '../../../core/model/AppState';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { CustomEmojiPrefetchCoordinator } from '../../../domain/usecases/customEmojiPrefetch';
import { ChatTimelineEntryVO } from './ChatTimelineVO';

const DOMAIN = 0x00D3;
const TAG = 'ChatMessageCustomEmoji';

export interface ChatMessageCustomEmojiState {
  chatId: number;
  pageLifecycleToken: number;
  inFlight: boolean;
  resolvedChatIds: Set<number>;
}

export function createCustomEmojiState(): ChatMessageCustomEmojiState {
  return {
    chatId: 0,
    pageLifecycleToken: 0,
    inFlight: false,
    resolvedChatIds: new Set<number>()
  };
}

let prefetchCoordinator: CustomEmojiPrefetchCoordinator | undefined;
let emojiState: ChatMessageCustomEmojiState = createCustomEmojiState();

function coordinator(): CustomEmojiPrefetchCoordinator {
  if (prefetchCoordinator === undefined) {
    prefetchCoordinator = new CustomEmojiPrefetchCoordinator(getTdGatewayAdapter());
  }
  return prefetchCoordinator;
}

// Every text/caption entity list carried by the rebuilt rows.
export function collectRowCustomEmojiEntities(entries: ChatTimelineEntryVO[]): TextEntity[][] {
  const lists: TextEntity[][] = [];
  for (const entry of entries) {
    if (entry.kind !== 'message') {
      continue;
    }
    if (entry.message.textEntities.length > 0) {
      lists.push(entry.message.textEntities);
    }
    if (entry.message.captionEntities.length > 0) {
      lists.push(entry.message.captionEntities);
    }
  }
  return lists;
}

export function resetMessageCustomEmojiState(): void {
  emojiState = createCustomEmojiState();
}

// Fire-and-forget: resolves missing files for the rebuilt rows and rebuilds once when new files landed.
export function prefetchMessageCustomEmoji(activeChatId: number,
  entries: ChatTimelineEntryVO[],
  rebuild: () => void): void {
  const lists = collectRowCustomEmojiEntities(entries);
  if (lists.length === 0) {
    return;
  }
  const chatId = activeChatId;
  // A different chat means a fresh visit: the previous pass no longer applies to what is on screen.
  if (emojiState.chatId !== chatId) {
    emojiState = createCustomEmojiState();
    emojiState.chatId = chatId;
  }
  if (emojiState.inFlight || emojiState.resolvedChatIds.has(chatId)) {
    // One pass per chat visit: a new file set means a new visit or a file update, not another loop.
    return;
  }
  emojiState.inFlight = true;
  emojiState.chatId = chatId;
  coordinator().prefetch(lists)
    .then((filled: number): void => {
      emojiState.inFlight = false;
      if (filled === 0) {
        emojiState.resolvedChatIds.add(chatId);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Resolved %{public}d custom emoji files for chat %{public}d', filled, chatId);
      // The row key carries the resolved paths, so a rebuild is what makes them visible.
      emojiState.resolvedChatIds.add(chatId);
      rebuild();
    })
    .catch((error: Error): void => {
      emojiState.inFlight = false;
      hilog.warn(DOMAIN, TAG, 'Custom emoji prefetch failed: %{public}s', error.message);
    });
}

// A file update or a chat switch allows a fresh pass.
export function invalidateMessageCustomEmoji(chatId: number): void {
  emojiState.resolvedChatIds.delete(chatId);
}
