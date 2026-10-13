import { ChatScreenViewState } from '../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { ChatScreenSession } from '../../../main/ets/ui/pages/chat/ChatScreenSession';
import { uiObserver } from '@kit.ArkUI';

// Used only by the test-page indicators. The real page owns its own production session.
export class ChatScreenDecompositionFixture {
  static readonly view: ChatScreenViewState = new ChatScreenViewState();
  static readonly session: ChatScreenSession = new ChatScreenSession(
    ChatScreenDecompositionFixture.view,
    (): UIContext => { throw new Error('The V2 render probe must not request UIContext'); },
    (): uiObserver.NavigationInfo | undefined => {
      throw new Error('The V2 render probe must not request navigation information');
    }
  );
}
