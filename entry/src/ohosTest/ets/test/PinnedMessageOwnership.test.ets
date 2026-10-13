import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, SearchChatMessagesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppState, ReducerAction } from '../../../main/ets/core/model/AppState';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { PinnedMessageInfo } from '../../../main/ets/domain/usecases/loadPinnedMessage';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ChatScreenRouteParams } from '../../../main/ets/ui/pages/chat/ChatScreenRouteParams';
import {
  ChatPinnedMessagesCoordinatorPort, loadPinnedMessage, loadMorePinnedMessages,
  loadSinglePinnedMessageFallback, resetPinnedMessageState, applyPinnedMessageInfo
} from '../../../main/ets/ui/pages/chat/ChatPinnedMessagesCoordinator';

// Actual coordinator, use case, parser, route, lease and AppStore scopes. Only
// the account-tagged transport and current-store registry boundary are fixtures.
// No app bootstrap, native client, UI, account action or network request occurs.
// Host additionally executes the real route predicate and Session delegates.
class PendingPinnedRequest {
  readonly account: string;
  readonly command: AnyAppCommand;
  readonly promise: Promise<Object>;
  private resolve?: (value: Object) => void;
  private reject?: (error: Error) => void;
  constructor(account: string, command: AnyAppCommand) {
    this.account = account;
    this.command = command;
    this.promise = new Promise<Object>((resolve, reject) => { this.resolve = resolve; this.reject = reject; });
  }
  succeed(response: TdObject): void {
    const resolve = this.resolve;
    if (resolve === undefined) throw new Error('Missing fixture resolution');
    resolve(response);
  }
  fail(): void {
    const reject = this.reject;
    if (reject === undefined) throw new Error('Missing fixture rejection');
    reject(new Error('Account-tagged synthetic request failure'));
  }
}

class PinnedGateway implements TdGatewayPort {
  readonly requests: PendingPinnedRequest[] = [];
  readonly account: string;
  constructor(account: string) { this.account = account; }
  async initialize(): Promise<void> { throw new Error('Native initialization is forbidden'); }
  send(command: AnyAppCommand): Promise<Object> {
    if (command.type !== 'searchChatMessages' && command.type !== 'getChatPinnedMessage') {
      throw new Error('Unexpected capability in pinned fixture: ' + command.type);
    }
    const request = new PendingPinnedRequest(this.account, command);
    this.requests.push(request);
    return request.promise;
  }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' { return 'ready'; }
  async destroy(): Promise<void> {}
}

function fixtureStore(): AppStore {
  return new AppStore((state: AppState, _action: ReducerAction): AppState => state, undefined, false);
}

function pin(id: string): PinnedMessageInfo {
  const result = new PinnedMessageInfo();
  result.isAvailable = true; result.messageId = id; result.preview = 'pin' + id;
  return result;
}

function messageResponse(id: string): TdObject {
  return TdObject.fromJSON('{"@type":"message","id":"' + id + '","chat_id":42,"date":1,' +
    '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"pin' + id + '"}}}');
}

function pageResponse(ids: string[], cursor: string = '0', total: number = ids.length): TdObject {
  const messages: string[] = ids.map((id: string): string =>
    '{"@type":"message","id":"' + id + '","chat_id":42,"date":1,' +
    '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"pin' + id + '"}}}');
  return TdObject.fromJSON('{"@type":"foundChatMessages","messages":[' + messages.join(',') +
    '],"next_from_message_id":"' + cursor + '","total_count":' + total.toString() + '}');
}

async function settlePinned(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(() => resolve(), 0); });
}

class PinnedFixture implements ChatPinnedMessagesCoordinatorPort {
  static latest?: PinnedFixture;
  readonly storeA: AppStore = fixtureStore();
  readonly storeB: AppStore = fixtureStore();
  readonly gatewayA: PinnedGateway = new PinnedGateway('A');
  readonly gatewayB: PinnedGateway = new PinnedGateway('B');
  currentStore: AppStore = this.storeA;
  routeContext?: ChatScreenRouteParams = new ChatScreenRouteParams(42, 'Synthetic route A', this.storeA, this.gatewayA);
  routeActivated: boolean = true;
  activeChatId: number = 42;
  pageLifecycleToken: number = 1;
  pinnedMessageRequestId: number = 0;
  pinnedMessagesListRequestId: number = 0;
  pinnedMessageDismissedId: string = '0';
  pinnedMessageVisible: boolean = false;
  pinnedMessageId: string = '0';
  pinnedMessagePreview: string = '';
  pinnedMessageHasThumbnail: boolean = false;
  pinnedMessageThumbnailPath: string = '';
  pinnedMessageIndex: number = 0;
  pinnedMessageTotalCount: number = 1;
  pinnedMessages: PinnedMessageInfo[] = [];
  pinnedMessagesNextFromMessageId: string = '0';
  pinnedMessagesListLoading: boolean = false;
  pinnedMessagesListVisible: boolean = false;
  constructor() { PinnedFixture.latest = this; }
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean {
    // This is the explicit registry boundary; scope revocation and lease state
    // are the real production implementations, with no fake epoch counter.
    return this.routeContext === route && route.isCurrentAccount(this.currentStore) && !route.openLease.isReleased();
  }
  loadSinglePinnedMessageFallback(chat: number, lifecycle: number, request: number): void {
    loadSinglePinnedMessageFallback(this, chat, lifecycle, request);
  }
  resetPinnedMessageState(): void { resetPinnedMessageState(this); }
  applyPinnedMessageInfo(info: PinnedMessageInfo, index: number, count: number): void {
    applyPinnedMessageInfo(this, info, index, count);
  }
  handlePinnedMessagePress(): void { throw new Error('Unexpected UI action'); }
  jumpToMessageId(_id: string): void { throw new Error('Unexpected timeline mutation'); }
  pinnedMessageTitle(_index: number, _total: number): string { throw new Error('Unexpected presentation request'); }
  scheduleLifecycleTask(_delay: number, _task: () => void): void { throw new Error('Unexpected lifecycle timer'); }
  setPinnedMessagesListVisible(_visible: boolean): void { throw new Error('Unexpected UI animation'); }
  getUIContext(): UIContext { throw new Error('Native UI context is forbidden'); }
  retire(mode: string): void {
    if (mode === 'scope') this.storeA.invalidateScopes();
    else if (mode === 'account') this.currentStore = this.storeB;
    else if (mode === 'route') this.routeContext = new ChatScreenRouteParams(42, 'Replacement A', this.storeA, this.gatewayA);
    else if (mode === 'account-aba') {
      this.storeA.invalidateScopes(); this.currentStore = this.storeB; this.currentStore = this.storeA;
    } else if (mode === 'release') {
      const route = this.routeContext;
      if (route === undefined) throw new Error('Missing fixture route');
      route.openLease.release();
    } else if (mode === 'inactive') this.routeActivated = false;
    else if (mode === 'no-route') this.routeContext = undefined;
    else if (mode === 'chat') this.activeChatId = 43;
    else if (mode === 'lifecycle') this.pageLifecycleToken++;
    else throw new Error('Unknown retirement fixture: ' + mode);
  }
  seed(id: string = '900', cursor: string = '800', loading: boolean = false): void {
    this.pinnedMessages = [pin(id)]; this.applyPinnedMessageInfo(this.pinnedMessages[0], 3, 4);
    this.pinnedMessagesNextFromMessageId = cursor; this.pinnedMessagesListLoading = loading;
    this.pinnedMessagesListVisible = true; this.pinnedMessageHasThumbnail = true;
    this.pinnedMessageThumbnailPath = '/synthetic/' + id + '.jpg';
  }
  stateKey(): string {
    return [this.pinnedMessageId, this.pinnedMessagePreview, this.pinnedMessageHasThumbnail.toString(),
      this.pinnedMessageThumbnailPath, this.pinnedMessageIndex.toString(), this.pinnedMessageTotalCount.toString(),
      this.pinnedMessageVisible.toString(), this.pinnedMessageDismissedId,
      this.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId + ':' + item.preview).join('|'),
      this.pinnedMessagesNextFromMessageId, this.pinnedMessagesListLoading.toString(),
      this.pinnedMessagesListVisible.toString(), this.pinnedMessageRequestId.toString(),
      this.pinnedMessagesListRequestId.toString()].join(';');
  }
  assertNoReplacementTransport(): void { expect(this.gatewayB.requests.length).assertEqual(0); }
}

function finish(request: PendingPinnedRequest, outcome: string, single: boolean = false): void {
  if (outcome === 'error') request.fail();
  else if (outcome === 'empty') request.succeed(single
    ? TdObject.fromJSON('{"@type":"error","code":404,"message":"Synthetic absence"}') : pageResponse([]));
  else request.succeed(single ? messageResponse('111') : pageResponse(['111'], '100'));
}

export default function pinnedMessageOwnershipTest() {
  describe('PinnedMessageOwnership', () => {
    it('preserves current route initial pins and exact search command/cursor contract', 0, async () => {
      const host = new PinnedFixture();
      loadPinnedMessage(host);
      expect(host.gatewayA.requests.length).assertEqual(1);
      const command = host.gatewayA.requests[0].command as SearchChatMessagesCommand;
      expect(command.type).assertEqual('searchChatMessages'); expect(command.payload.chatId).assertEqual(42);
      expect(command.payload.filterType).assertEqual('Pinned'); expect(command.payload.fromMessageId).assertEqual('0');
      host.gatewayA.requests[0].succeed(pageResponse(['9223372036854775001'], '9223372036854774900', 3));
      await settlePinned();
      expect(host.pinnedMessageId).assertEqual('9223372036854775001'); expect(host.pinnedMessageTotalCount).assertEqual(3);
      expect(host.pinnedMessagesNextFromMessageId).assertEqual('9223372036854774900'); host.assertNoReplacementTransport();
    });

    for (const initial of ['empty', 'error']) {
      it(`current ${initial} search falls back exactly once through the owning account`, 0, async () => {
        const host = new PinnedFixture(); loadPinnedMessage(host);
        finish(host.gatewayA.requests[0], initial); await settlePinned();
        expect(host.gatewayA.requests.length).assertEqual(2);
        expect(host.gatewayA.requests[1].command.type).assertEqual('getChatPinnedMessage');
        host.gatewayA.requests[1].succeed(messageResponse('112')); await settlePinned();
        expect(host.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId).join(',')).assertEqual('112');
        expect(host.pinnedMessageId).assertEqual('112'); expect(host.pinnedMessageTotalCount).assertEqual(1);
        host.assertNoReplacementTransport();
      });
    }

    for (const outcome of ['empty', 'error']) {
      it(`current fallback ${outcome} resets pins and pagination`, 0, async () => {
        const host = new PinnedFixture(); host.seed(); loadPinnedMessage(host);
        finish(host.gatewayA.requests[0], 'empty'); await settlePinned();
        finish(host.gatewayA.requests[1], outcome, true); await settlePinned();
        expect(host.pinnedMessageId).assertEqual('0'); expect(host.pinnedMessages.length).assertEqual(0);
        expect(host.pinnedMessageVisible).assertFalse(); expect(host.pinnedMessagesNextFromMessageId).assertEqual('0');
        expect(host.pinnedMessagesListLoading).assertFalse(); host.assertNoReplacementTransport();
      });
    }

    for (const mode of ['scope', 'account', 'release', 'inactive', 'no-route', 'chat']) {
      it(`revoked ${mode} owner cannot dispatch initial, fallback or pagination`, 0, async () => {
        const host = new PinnedFixture(); host.seed(); host.retire(mode);
        const before = host.stateKey(); loadPinnedMessage(host);
        host.loadSinglePinnedMessageFallback(42, host.pageLifecycleToken, host.pinnedMessageRequestId);
        loadMorePinnedMessages(host);
        await settlePinned();
        expect(host.gatewayA.requests.length).assertEqual(0); host.assertNoReplacementTransport();
        expect(host.stateKey()).assertEqual(before);
      });
    }

    for (const mode of ['scope', 'account', 'route', 'account-aba', 'release', 'inactive', 'lifecycle']) {
      for (const outcome of ['success', 'empty', 'error']) {
        it(`old initial ${outcome} after ${mode} retirement neither publishes nor dispatches fallback`, 0, async () => {
          const host = new PinnedFixture(); loadPinnedMessage(host);
          host.retire(mode); host.seed('900', '800', true);
          const before = host.stateKey(), items = host.pinnedMessages;
          finish(host.gatewayA.requests[0], outcome); await settlePinned();
          expect(host.gatewayA.requests.length).assertEqual(1); host.assertNoReplacementTransport();
          expect(host.stateKey()).assertEqual(before); expect(host.pinnedMessages === items).assertTrue();
        });
      }
    }

    for (const mode of ['scope', 'route', 'account-aba']) {
      for (const outcome of ['success', 'empty', 'error']) {
        it(`pending fallback ${outcome} after ${mode} retirement preserves replacement pins and loading`, 0, async () => {
          const host = new PinnedFixture(); loadPinnedMessage(host);
          finish(host.gatewayA.requests[0], 'empty'); await settlePinned();
          expect(host.gatewayA.requests.length).assertEqual(2);
          host.retire(mode); host.seed('900', '800', true);
          const before = host.stateKey(), items = host.pinnedMessages;
          finish(host.gatewayA.requests[1], outcome, true); await settlePinned();
          expect(host.stateKey()).assertEqual(before); expect(host.pinnedMessages === items).assertTrue();
          expect(host.gatewayA.requests.length).assertEqual(2); host.assertNoReplacementTransport();
        });
      }
    }

    for (const mode of ['scope', 'route', 'account-aba']) {
      for (const outcome of ['success', 'error']) {
        it(`old pagination ${outcome} after ${mode} retirement cannot merge or release replacement loading`, 0, async () => {
          const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host);
          expect(host.gatewayA.requests.length).assertEqual(1); expect(host.pinnedMessagesListLoading).assertTrue();
          host.retire(mode); host.seed('900', '800', true);
          const before = host.stateKey(), items = host.pinnedMessages;
          finish(host.gatewayA.requests[0], outcome); await settlePinned();
          expect(host.stateKey()).assertEqual(before); expect(host.pinnedMessages === items).assertTrue();
          host.assertNoReplacementTransport();
        });
      }
    }

    it('current pagination deduplicates and terminates a repeated cursor', 0, async () => {
      const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host);
      const command = host.gatewayA.requests[0].command as SearchChatMessagesCommand;
      expect(command.payload.fromMessageId).assertEqual('100');
      host.gatewayA.requests[0].succeed(pageResponse(['10', '60', '60'], '100', 5)); await settlePinned();
      expect(host.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId).join(',')).assertEqual('10,60');
      expect(host.pinnedMessagesNextFromMessageId).assertEqual('0'); expect(host.pinnedMessagesListLoading).assertFalse();
      expect(host.pinnedMessageTotalCount).assertEqual(5); loadMorePinnedMessages(host);
      expect(host.gatewayA.requests.length).assertEqual(1);
    });

    it('current pagination rejection permits an explicit same-cursor retry', 0, async () => {
      const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host);
      host.gatewayA.requests[0].fail(); await settlePinned();
      expect(host.pinnedMessagesListLoading).assertFalse(); expect(host.pinnedMessagesNextFromMessageId).assertEqual('100');
      loadMorePinnedMessages(host); expect(host.gatewayA.requests.length).assertEqual(2);
      host.gatewayA.requests[1].succeed(pageResponse(['60'], '50')); await settlePinned();
      expect(host.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId).join(',')).assertEqual('10,60');
      expect(host.pinnedMessagesNextFromMessageId).assertEqual('50'); expect(host.pinnedMessagesListLoading).assertFalse();
    });

    for (const outcome of ['success', 'error']) {
      it(`refresh rejects old page ${outcome} against the new base snapshot`, 0, async () => {
        const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host); loadPinnedMessage(host);
        host.gatewayA.requests[1].succeed(pageResponse(['900'], '800', 4)); await settlePinned();
        const before = host.stateKey(), items = host.pinnedMessages;
        finish(host.gatewayA.requests[0], outcome); await settlePinned();
        expect(host.stateKey()).assertEqual(before); expect(host.pinnedMessages === items).assertTrue();
      });
      it(`old page ${outcome} cannot clear a newer pending page after refresh`, 0, async () => {
        const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host); loadPinnedMessage(host);
        host.gatewayA.requests[1].succeed(pageResponse(['900'], '800')); await settlePinned();
        loadMorePinnedMessages(host); expect(host.gatewayA.requests.length).assertEqual(3);
        const before = host.stateKey(); finish(host.gatewayA.requests[0], outcome); await settlePinned();
        expect(host.stateKey()).assertEqual(before); expect(host.pinnedMessagesListLoading).assertTrue();
        host.gatewayA.requests[2].succeed(pageResponse(['700'], '600')); await settlePinned();
        expect(host.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId).join(',')).assertEqual('900,700');
      });
    }

    it('refresh blocks old-cursor pagination until its initial snapshot resolves', 0, async () => {
      const host = new PinnedFixture(); host.seed('10', '100'); loadMorePinnedMessages(host); loadPinnedMessage(host);
      host.gatewayA.requests[0].fail(); await settlePinned(); loadMorePinnedMessages(host);
      expect(host.gatewayA.requests.length).assertEqual(2);
      expect(host.pinnedMessagesNextFromMessageId).assertEqual('0');
      host.gatewayA.requests[1].succeed(pageResponse(['900'], '800')); await settlePinned();
      loadMorePinnedMessages(host); expect(host.gatewayA.requests.length).assertEqual(3);
      expect((host.gatewayA.requests[2].command as SearchChatMessagesCommand).payload.fromMessageId).assertEqual('800');
      host.gatewayA.requests[2].succeed(pageResponse(['700'], '0')); await settlePinned();
      expect(host.pinnedMessages.map((item: PinnedMessageInfo): string => item.messageId).join(',')).assertEqual('900,700');
    });

    for (const outcome of ['success', 'empty', 'error']) {
      it(`latest initial request defeats duplicate old ${outcome} completion`, 0, async () => {
        const host = new PinnedFixture(); loadPinnedMessage(host); loadPinnedMessage(host);
        host.gatewayA.requests[1].succeed(pageResponse(['900'], '800')); await settlePinned();
        const before = host.stateKey(); finish(host.gatewayA.requests[0], outcome); await settlePinned();
        expect(host.stateKey()).assertEqual(before); expect(host.gatewayA.requests.length).assertEqual(2);
      });
    }

    it('a new refresh defeats an already pending old fallback', 0, async () => {
      const host = new PinnedFixture(); loadPinnedMessage(host); finish(host.gatewayA.requests[0], 'empty'); await settlePinned();
      loadPinnedMessage(host); host.gatewayA.requests[2].succeed(pageResponse(['900'], '800')); await settlePinned();
      const before = host.stateKey(); host.gatewayA.requests[1].succeed(messageResponse('111')); await settlePinned();
      expect(host.stateKey()).assertEqual(before); expect(host.gatewayA.requests.length).assertEqual(3);
    });
  });
}
