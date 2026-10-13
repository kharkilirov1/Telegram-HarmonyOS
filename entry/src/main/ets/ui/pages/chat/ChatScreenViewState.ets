import { ChatChromeState } from './ChatChromeState';
import { ChatComposerState } from './ChatComposerState';
import { ChatPanelsState } from './ChatPanelsState';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatPinnedSearchState } from './ChatPinnedSearchState';

// Stable aggregate: each field has one @Trace backing property in its owning slice.
export class ChatScreenViewState {
  readonly chrome: ChatChromeState = new ChatChromeState();
  readonly composer: ChatComposerState = new ChatComposerState();
  readonly panels: ChatPanelsState = new ChatPanelsState();
  readonly timeline: ChatTimelineViewState = new ChatTimelineViewState();
  readonly media: ChatMediaViewState = new ChatMediaViewState();
  readonly pinnedSearch: ChatPinnedSearchState = new ChatPinnedSearchState();
}
