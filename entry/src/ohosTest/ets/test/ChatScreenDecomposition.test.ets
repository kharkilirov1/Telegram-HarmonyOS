import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@kit.TestKit';
import { uiObserver } from '@kit.ArkUI';
import { ChatScreenViewState } from '../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { ChatScreenSession } from '../../../main/ets/ui/pages/chat/ChatScreenSession';
import { ChatChromeState } from '../../../main/ets/ui/pages/chat/ChatChromeState';
import { ChatComposerState } from '../../../main/ets/ui/pages/chat/ChatComposerState';
import { ChatPanelsState } from '../../../main/ets/ui/pages/chat/ChatPanelsState';
import { ChatTimelineViewState } from '../../../main/ets/ui/pages/chat/ChatTimelineViewState';
import { ChatMediaViewState } from '../../../main/ets/ui/pages/chat/ChatMediaViewState';
import { ChatPinnedSearchState } from '../../../main/ets/ui/pages/chat/ChatPinnedSearchState';
import { ChatTimelineEntryVO } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import { ChatTimelineDataSource } from '../../../main/ets/ui/pages/chat/ChatTimelineDataSource';
import { ChatScrollPositionCache } from '../../../main/ets/ui/pages/chat/ChatScrollPositionCache';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { ChatScreenDecompositionFixture } from '../testability/ChatScreenDecompositionFixture';

// These are real production instances. No host body extraction, fake UIContext,
// TDLib initialize, account scope, gateway, app bootstrap or transport is used.
class SessionFixture {
  readonly view: ChatScreenViewState = new ChatScreenViewState();
  readonly session: ChatScreenSession;
  uiContextCalls: number = 0;
  navigationInfoCalls: number = 0;

  constructor() {
    this.session = new ChatScreenSession(this.view,
      (): UIContext => {
        this.uiContextCalls++;
        throw new Error('Unexpected UIContext request in a pure session test');
      },
      (): uiObserver.NavigationInfo | undefined => {
        this.navigationInfoCalls++;
        throw new Error('Unexpected navigation information request in a pure session test');
      });
  }

  assertPlatformCallbacksUnused(): void {
    expect(this.uiContextCalls).assertEqual(0);
    expect(this.navigationInfoCalls).assertEqual(0);
  }
}

function timelineEntry(key: string): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = 'date';
  entry.key = key;
  entry.stableKey = key;
  entry.dateText = key;
  return entry;
}

function timelineMessage(key: string, text: string): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.key = key;
  entry.stableKey = key;
  entry.message.messageId = key;
  entry.message.text = text;
  return entry;
}

class TimelineChangeRecorder implements DataChangeListener {
  added: number[] = [];
  changed: number[] = [];
  deleted: number[] = [];
  moved: number = 0;
  reloaded: number = 0;
  batched: number = 0;

  onDataAdd(index: number): void { this.added.push(index); }
  onDataChange(index: number): void { this.changed.push(index); }
  onDataDelete(index: number): void { this.deleted.push(index); }
  onDataMove(from: number, to: number): void { this.moved++; }
  onDataReloaded(): void { this.reloaded++; }
  onDatasetChange(operations: DataOperation[]): void { this.batched++; }
  onDataAdded(index: number): void { this.onDataAdd(index); }
  onDataChanged(index: number): void { this.onDataChange(index); }
  onDataDeleted(index: number): void { this.onDataDelete(index); }
  onDataMoved(from: number, to: number): void { this.onDataMove(from, to); }

  assertNoOtherNotifications(): void {
    expect(this.deleted.length).assertEqual(0);
    expect(this.moved).assertEqual(0);
    expect(this.reloaded).assertEqual(0);
    expect(this.batched).assertEqual(0);
  }
}

async function allowTimerTurn(): Promise<void> {
  await new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 40);
  });
}

// The Driver waits are nullable; assertions must also prove presence/absence.
async function assertVisibleText(driver: Driver, value: string): Promise<void> {
  const selector = ON.text(value);
  const component = await driver.waitForComponent(selector, 2000);
  expect(component === undefined || component === null).assertFalse();
  await driver.assertComponentExist(selector);
}

async function assertTextAbsent(driver: Driver, value: string): Promise<void> {
  const components = await driver.findComponents(ON.text(value));
  const count = components === undefined || components === null ? 0 : components.length;
  expect(count).assertEqual(0);
}

export default function chatScreenDecompositionTest() {
  describe('ChatScreenDecomposition', () => {
    it('constructs the six real observed models and keeps stable slice identities', 0, () => {
      const fixture = new SessionFixture();
      const view = fixture.view;
      const chrome = view.chrome;
      const composer = view.composer;
      const panels = view.panels;
      const timeline = view.timeline;
      const media = view.media;
      const pinnedSearch = view.pinnedSearch;

      expect(chrome instanceof ChatChromeState).assertTrue();
      expect(composer instanceof ChatComposerState).assertTrue();
      expect(panels instanceof ChatPanelsState).assertTrue();
      expect(timeline instanceof ChatTimelineViewState).assertTrue();
      expect(media instanceof ChatMediaViewState).assertTrue();
      expect(pinnedSearch instanceof ChatPinnedSearchState).assertTrue();
      expect(fixture.session.view === view).assertTrue();

      fixture.session.title = 'fixture title';
      fixture.session.setDraftText('fixture draft');
      fixture.session.activeStickerTabId = 'fixture tab';
      fixture.session.listInitialIndex = 3;
      fixture.session.activeVoiceProgress = 0.25;
      fixture.session.setSearchQuery('fixture search');

      expect(view.chrome === chrome).assertTrue();
      expect(view.composer === composer).assertTrue();
      expect(view.panels === panels).assertTrue();
      expect(view.timeline === timeline).assertTrue();
      expect(view.media === media).assertTrue();
      expect(view.pinnedSearch === pinnedSearch).assertTrue();
      fixture.assertPlatformCallbacksUnused();
    });

    it('routes old names to one backing property in both directions across every slice', 0, () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      const view = fixture.view;
      const stack = new NavPathStack();
      session.pageStack = stack;
      session.activeChatId = 901;
      session.composerDraftText = 'draft';
      session.activeStickerTabId = 'favorites';
      session.listInitialIndex = 5;
      session.activeVoiceProgress = 0.75;
      session.searchQuery = 'query';

      expect(view.chrome.pageStack === stack).assertTrue();
      expect(view.chrome.activeChatId).assertEqual(901);
      expect(view.composer.composerDraftText).assertEqual('draft');
      expect(view.panels.activeStickerTabId).assertEqual('favorites');
      expect(view.timeline.listInitialIndex).assertEqual(5);
      expect(view.media.activeVoiceProgress).assertEqual(0.75);
      expect(view.pinnedSearch.searchQuery).assertEqual('query');

      view.chrome.activeChatId = 902;
      view.composer.composerDraftText = 'revised';
      view.panels.activeStickerTabId = 'recent';
      view.timeline.listInitialIndex = 2;
      view.media.activeVoiceProgress = 0.5;
      view.pinnedSearch.searchQuery = 'revised query';
      expect(session.getActiveChatId()).assertEqual(902);
      expect(session.getDraftText()).assertEqual('revised');
      expect(session.activeStickerTabId).assertEqual('recent');
      expect(session.listInitialIndex).assertEqual(2);
      expect(session.activeVoiceProgress).assertEqual(0.5);
      expect(session.getSearchQuery()).assertEqual('revised query');
      fixture.assertPlatformCallbacksUnused();
    });

    it('keeps draft arrays and presentation isolated between page sessions', 0, () => {
      const first = new SessionFixture();
      const second = new SessionFixture();
      first.session.activeChatId = 11;
      first.session.setDraftText('first draft');
      first.session.pendingAttachmentUris.push('fixture attachment');
      first.session.pinnedMessageVisible = true;

      expect(second.session.activeChatId).assertEqual(0);
      expect(second.session.getDraftText()).assertEqual('');
      expect(second.session.pendingAttachmentUris.length).assertEqual(0);
      expect(second.session.pinnedMessageVisible).assertFalse();
      expect(first.session.pendingAttachmentUris === first.view.composer.pendingAttachmentUris).assertTrue();
      expect(first.session.pendingAttachmentUris === second.session.pendingAttachmentUris).assertFalse();
      first.assertPlatformCallbacksUnused();
      second.assertPlatformCallbacksUnused();
    });

    it('retires the real shared send operation even when resetting an already idle session', 0, () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      const before = session.getSendOperationToken();
      session.setSendingMessage(true);
      expect(session.isSendingMessage()).assertTrue();
      expect(session.getSendOperationToken()).assertEqual(before + 1);
      session.setSendingMessage(false);
      session.setSendingMessage(false);
      expect(session.isSendingMessage()).assertFalse();
      expect(session.getSendOperationToken()).assertEqual(before + 3);
      fixture.assertPlatformCallbacksUnused();
    });

    it('restores a saved stable key after prepend and prioritizes the unread boundary', 0, () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      const chatId = 901001;
      const previous = ChatScrollPositionCache.positions.get(chatId);
      try {
        session.activeChatId = chatId;
        session.currentScrollChatId = chatId;
        session.dataSource.applyDiff([timelineEntry('old'), timelineEntry('saved'), timelineEntry('last')]);
        session.lastVisibleStartIndex = 1;
        session.saveScrollPosition();
        expect(ChatScrollPositionCache.positions.get(chatId)).assertEqual('saved');

        session.dataSource.applyDiff([
          timelineEntry('prepend'), timelineEntry('old'), timelineEntry('saved'), timelineEntry('last')
        ]);
        session.computeInitialIndex(session.dataSource.totalCount());
        expect(fixture.view.timeline.listInitialIndex).assertEqual(2);

        session.unreadRestoreIndex = 0;
        session.computeInitialIndex(session.dataSource.totalCount());
        expect(fixture.view.timeline.listInitialIndex).assertEqual(0);

        session.unreadRestoreIndex = -1;
        ChatScrollPositionCache.positions.set(chatId, 'missing key');
        session.computeInitialIndex(session.dataSource.totalCount());
        expect(fixture.view.timeline.listInitialIndex).assertEqual(3);
        session.computeInitialIndex(0);
        expect(fixture.view.timeline.listInitialIndex).assertEqual(0);
        fixture.assertPlatformCallbacksUnused();
      } finally {
        if (previous === undefined) ChatScrollPositionCache.positions.delete(chatId);
        else ChatScrollPositionCache.positions.set(chatId, previous);
      }
    });

    it('preserves the prepend comparison snapshot and only notifies changed existing content', 0, () => {
      const dataSource = new ChatTimelineDataSource();
      dataSource.applyDiff([timelineEntry('anchor'), timelineEntry('tail')]);
      const recorder = new TimelineChangeRecorder();
      dataSource.registerDataChangeListener(recorder);
      const changedTail = timelineEntry('tail');
      changedTail.dateText = 'updated tail';

      dataSource.applyDiff([timelineEntry('prepend'), timelineEntry('anchor'), changedTail]);

      expect(dataSource.totalCount()).assertEqual(3);
      expect(dataSource.getLastPrependCount()).assertEqual(1);
      expect(dataSource.getData(0).key).assertEqual('prepend');
      expect(dataSource.getData(1).key).assertEqual('anchor');
      expect(dataSource.getData(2).key).assertEqual('tail');
      expect(dataSource.getData(2).dateText).assertEqual('updated tail');
      expect(dataSource.findIndexByKey('anchor')).assertEqual(1);
      expect(recorder.added.join(',')).assertEqual('0');
      expect(recorder.changed.join(',')).assertEqual('2');
      recorder.assertNoOtherNotifications();
      dataSource.unregisterDataChangeListener(recorder);
    });

    it('preserves the anchor snapshot and emits an add for the appended tail after prepend', 0, () => {
      const dataSource = new ChatTimelineDataSource();
      dataSource.applyDiff([timelineMessage('anchor', 'old anchor'), timelineMessage('second', 'second')]);
      const recorder = new TimelineChangeRecorder();
      dataSource.registerDataChangeListener(recorder);

      // Two old messages match from index 1; a new tail makes the strict prepend
      // offset equal to 2, so only detectPrependByAnchor can handle this update.
      dataSource.applyDiff([
        timelineMessage('prepend', 'prepend'), timelineMessage('anchor', 'updated anchor'),
        timelineMessage('second', 'second'), timelineMessage('append', 'new tail')
      ]);

      expect(dataSource.totalCount()).assertEqual(4);
      expect(dataSource.getLastPrependCount()).assertEqual(1);
      expect(dataSource.getData(0).key).assertEqual('prepend');
      expect(dataSource.getData(1).key).assertEqual('anchor');
      expect(dataSource.getData(1).message.text).assertEqual('updated anchor');
      expect(dataSource.getData(2).key).assertEqual('second');
      expect(dataSource.getData(3).key).assertEqual('append');
      expect(dataSource.getData(3).message.text).assertEqual('new tail');
      expect(dataSource.findIndexByKey('anchor')).assertEqual(1);
      expect(dataSource.findIndexByKey('append')).assertEqual(3);
      expect(recorder.added.join(',')).assertEqual('0,3');
      expect(recorder.changed.join(',')).assertEqual('1');
      recorder.assertNoOtherNotifications();
      dataSource.unregisterDataChangeListener(recorder);
    });

    it('keeps the saved anchor when the visible index is invalid and skips empty restore work', 0, () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      const chatId = 901002;
      const previous = ChatScrollPositionCache.positions.get(chatId);
      try {
        ChatScrollPositionCache.positions.set(chatId, 'existing anchor');
        session.currentScrollChatId = chatId;
        session.lastVisibleStartIndex = -1;
        session.saveScrollPosition();
        expect(ChatScrollPositionCache.positions.get(chatId)).assertEqual('existing anchor');
        session.awaitingInitialTimeline = true;
        session.restoreScrollPosition();
        expect(session.awaitingInitialTimeline).assertTrue();
        expect(session.suppressLoadOlderUntil).assertEqual(0);
        expect(session.transientTimerIds.size).assertEqual(0);
        fixture.assertPlatformCallbacksUnused();
      } finally {
        if (previous === undefined) ChatScrollPositionCache.positions.delete(chatId);
        else ChatScrollPositionCache.positions.set(chatId, previous);
      }
    });

    it('rejects an empty route without binding an account or requesting platform callbacks', 0, () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      session.aboutToAppear();
      session.bindChatRoute(undefined);
      session.handleNavShown();
      expect(session.routeActivated).assertFalse();
      expect(session.routeContext === undefined).assertTrue();
      expect(session.accountStore === undefined).assertTrue();
      expect(session.chatGateway === undefined).assertTrue();
      expect(session.routeDataStarted).assertFalse();
      expect(session.pageLifecycleToken).assertEqual(0);
      expect(session.handleNavBackPressed()).assertFalse();
      fixture.assertPlatformCallbacksUnused();
    });

    it('runs current lifecycle tasks and prevents retired generation callbacks', 0, async () => {
      const fixture = new SessionFixture();
      const session = fixture.session;
      let currentRuns = 0;
      let staleRuns = 0;
      try {
        session.scheduleLifecycleTask(0, () => { currentRuns++; });
        await allowTimerTurn();
        expect(currentRuns).assertEqual(1);
        expect(session.transientTimerIds.size).assertEqual(0);

        session.scheduleLifecycleTask(0, () => { staleRuns++; });
        session.pageLifecycleToken++;
        await allowTimerTurn();
        expect(staleRuns).assertEqual(0);
        fixture.assertPlatformCallbacksUnused();
      } finally {
        session.clearTransientTimers();
      }
    });

    it('renders all six fixture Trace slices and mounts the actual empty-route chat page under Navigation', 0,
      async () => {
        const driver = Driver.create();
        // TestAbility loads testability/pages/Index. Indicators use the test-only
        // fixture Session; the mounted real ChatPage owns another production Session.
        // This case does not bind an authenticated account or start EntryAbility.
        await driver.waitForComponent(ON.id('chat-decomposition-open-empty-route'), 5000);
        await driver.assertComponentExist(ON.id('chat-decomposition-open-empty-route'));
        const session = ChatScreenDecompositionFixture.session;
        session.title = 'before title';
        session.setDraftText('before draft');
        session.activeStickerTabId = 'before tab';
        session.listInitialIndex = 4;
        session.activeVoiceProgress = 0.25;
        session.setSearchQuery('before search');
        await assertVisibleText(driver, 'chrome:before title');
        await assertVisibleText(driver, 'composer:before draft');
        await assertVisibleText(driver, 'panels:before tab');
        await assertVisibleText(driver, 'timeline:4');
        await assertVisibleText(driver, 'media:0.25');
        await assertVisibleText(driver, 'pinnedSearch:before search');

        session.title = 'observed title';
        session.setDraftText('observed draft');
        session.activeStickerTabId = 'observed tab';
        session.listInitialIndex = 7;
        session.activeVoiceProgress = 0.5;
        session.setSearchQuery('observed search');

        await assertVisibleText(driver, 'chrome:observed title');
        await assertVisibleText(driver, 'composer:observed draft');
        await assertVisibleText(driver, 'panels:observed tab');
        await assertVisibleText(driver, 'timeline:7');
        await assertVisibleText(driver, 'media:0.5');
        await assertVisibleText(driver, 'pinnedSearch:observed search');
        // Prove that each slice changed rather than retaining a stale indicator.
        await assertTextAbsent(driver, 'chrome:before title');
        await assertTextAbsent(driver, 'composer:before draft');
        await assertTextAbsent(driver, 'panels:before tab');
        await assertTextAbsent(driver, 'timeline:4');
        await assertTextAbsent(driver, 'media:0.25');
        await assertTextAbsent(driver, 'pinnedSearch:before search');

        const open = await driver.findComponent(ON.id('chat-decomposition-open-empty-route'));
        expect(open === undefined || open === null).assertFalse();
        await open.click();
        // Exact 'Chat' occurs in the actual top bar; the fixture title has another value.
        await driver.waitForComponent(ON.text('Chat'), 5000);
        await driver.assertComponentExist(ON.text('Chat'));
        await driver.assertComponentExist(ON.type('TextArea'));
        await driver.assertComponentExist(ON.text(localized($r('app.string.chat_not_selected').id,
          'Chat is not selected')));
        // No composer action, search, attach, media, account or transport operation is invoked.
        await driver.pressBack();
        await driver.waitForComponent(ON.id('chat-decomposition-open-empty-route'), 5000);
        await driver.assertComponentExist(ON.id('chat-decomposition-open-empty-route'));
        await driver.assertComponentExist(ON.text('chrome:observed title'));
        expect(ChatScreenDecompositionFixture.view.chrome.title).assertEqual('observed title');
      });
  });
}
