import { PinnedMessageInfo } from '../../../domain/usecases/loadPinnedMessage';

// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatPinnedSearchState {
  @Trace pinnedMessageVisible: boolean = false;
  @Trace pinnedMessageId: string = '0';
  @Trace pinnedMessagePreview: string = '';
  @Trace pinnedMessageHasThumbnail: boolean = false;
  @Trace pinnedMessageThumbnailPath: string = '';
  @Trace pinnedMessageIndex: number = 0;
  @Trace pinnedMessageTotalCount: number = 1;
  @Trace pinnedMessages: PinnedMessageInfo[] = [];
  @Trace pinnedMessagesNextFromMessageId: string = '0';
  @Trace pinnedMessagesListVisible: boolean = false;
  @Trace pinnedMessagesListLoading: boolean = false;
  @Trace isSearchMode: boolean = false;
  @Trace searchQuery: string = '';
  @Trace searchResultPos: number = 0;
  @Trace searchResultTotal: number = 0;
  @Trace searchResultLoaded: number = 0;
  @Trace searchLoading: boolean = false;
  @Trace searchError: boolean = false;
}
