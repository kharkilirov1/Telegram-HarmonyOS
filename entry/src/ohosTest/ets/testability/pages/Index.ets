import { TgChatScreenPage } from '../../../../main/ets/ui/pages/chat/TgChatScreenPage';
import { ChatChromeState } from '../../../../main/ets/ui/pages/chat/ChatChromeState';
import { ChatComposerState } from '../../../../main/ets/ui/pages/chat/ChatComposerState';
import { ChatPanelsState } from '../../../../main/ets/ui/pages/chat/ChatPanelsState';
import { ChatTimelineViewState } from '../../../../main/ets/ui/pages/chat/ChatTimelineViewState';
import { ChatMediaViewState } from '../../../../main/ets/ui/pages/chat/ChatMediaViewState';
import { ChatPinnedSearchState } from '../../../../main/ets/ui/pages/chat/ChatPinnedSearchState';
import { ChatScreenDecompositionFixture } from '../ChatScreenDecompositionFixture';
import { PhotoAlbumDialogFixtureView } from '../components/PhotoAlbumDialogFixture';
import { WriteResendFixtureView } from '../components/WriteResendFixture';
import { SequentialMediaDialogFixtureView } from '../components/SequentialMediaDialogFixture';
import { PhotoSelectionPreviewFixtureView } from '../components/PhotoSelectionPreviewFixture';
import { TimelineUpdateFixture, TimelineUpdateFixtureView, TIMELINE_UPDATE_ROUTE } from '../components/TimelineUpdateFixture';
import { SlowmodeNativeFixture, SlowmodeFixtureView } from '../components/SlowmodeFixture';

const EMPTY_CHAT_ROUTE = 'ChatScreenDecompositionEmptyRoute';
const SLOWMODE_FIXTURE_ROUTE = 'SlowmodeNativeFixtureRoute';

// These test-only indicators verify @Trace rendering of the actual six models.
// They do not implement or replace any production chat component.
@ComponentV2
struct ChatStateRenderProbe {
  @Require @Param chrome: ChatChromeState;
  @Require @Param composer: ChatComposerState;
  @Require @Param panels: ChatPanelsState;
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param pinnedSearch: ChatPinnedSearchState;

  build() {
    Column({ space: 8 }) {
      Text('chrome:' + this.chrome.title).id('chat-v2-chrome')
      Text('composer:' + this.composer.composerDraftText).id('chat-v2-composer')
      Text('panels:' + this.panels.activeStickerTabId).id('chat-v2-panels')
      Text('timeline:' + this.timeline.listInitialIndex.toString()).id('chat-v2-timeline')
      Text('media:' + this.media.activeVoiceProgress.toString()).id('chat-v2-media')
      Text('pinnedSearch:' + this.pinnedSearch.searchQuery).id('chat-v2-pinned-search')
    }
  }
}

@Entry
@ComponentV2
struct Index {
  @Local private pageStack: NavPathStack = new NavPathStack();
  aboutToAppear(): void { SlowmodeNativeFixture.bindNavigation(this.pageStack); }

  @Builder
  private chatDestination(name: string) {
    if (name === EMPTY_CHAT_ROUTE) {
      // No route parameter: real lifecycle guards leave account/transport unbound.
      TgChatScreenPage()
    } else if (name === TIMELINE_UPDATE_ROUTE) {
      TimelineUpdateFixtureView()
    } else if (name === SLOWMODE_FIXTURE_ROUTE) {
      NavDestination() { SlowmodeFixtureView() }.hideTitleBar(true)
    }
  }

  build() {
    Navigation(this.pageStack) {
      Scroll() {
      Column({ space: 16 }) {
        Text('Chat decomposition device fixture').fontSize(18)
        Button('Open mounted slowmode composer').id('slowmode-fixture-open-route').onClick(() => {
          SlowmodeNativeFixture.beforeRoutePush(this.pageStack);
          this.pageStack.pushPath({ name: SLOWMODE_FIXTURE_ROUTE }, false);
          SlowmodeNativeFixture.afterRoutePush(this.pageStack);
        })
        ChatStateRenderProbe({
          chrome: ChatScreenDecompositionFixture.view.chrome,
          composer: ChatScreenDecompositionFixture.view.composer,
          panels: ChatScreenDecompositionFixture.view.panels,
          timeline: ChatScreenDecompositionFixture.view.timeline,
          media: ChatScreenDecompositionFixture.view.media,
          pinnedSearch: ChatScreenDecompositionFixture.view.pinnedSearch
        })
        Button('Open empty chat composition')
          .id('chat-decomposition-open-empty-route')
          .onClick(() => {
            // Push after the page is built, rather than during aboutToAppear.
            this.pageStack.pushPath({ name: EMPTY_CHAT_ROUTE }, false);
          })
        PhotoAlbumDialogFixtureView()
        WriteResendFixtureView()
        SequentialMediaDialogFixtureView()
        PhotoSelectionPreviewFixtureView()
        Button('Open synthetic timeline updates')
          .id('timeline-update-open')
          .onClick(() => {
            TimelineUpdateFixture.prepare();
            this.pageStack.pushPath({ name: TIMELINE_UPDATE_ROUTE }, false);
          })
      }
      .width('100%')
      .padding(16)
      }
      .id('chat-test-fixture-scroll')
      .width('100%')
      .height('100%')
    }
    .navDestination(this.chatDestination)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}
